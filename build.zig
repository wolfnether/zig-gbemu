const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const main_module = b.addModule("main", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exec = b.addExecutable(.{
        .name = "gbemu",
        .root_module = main_module,
        .use_llvm = true,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib");
    exec.linkLibrary(raylib_artifact);
    exec.root_module.addImport("raylib", raylib);
    exec.root_module.addImport("raygui", raygui);
    exec.root_module.addImport("args", b.dependency("args", .{ .target = target, .optimize = optimize }).module("args"));

    const install = b.addInstallArtifact(exec, .{});

    //const installAssembly = b.addInstallBinFile(exec.getEmittedAsm(), "assembly.s");

    const build_step = b.step("build", "build main exe");
    build_step.dependOn(&install.step);
    //build_step.dependOn(&installAssembly.step);

    const run = b.addRunArtifact(exec);
    const run_step = b.step("run", "run main exec");
    run_step.dependOn(build_step);
    run_step.dependOn(&run.step);

    if (b.args) |args| {
        run.addArgs(args);
    }
}
