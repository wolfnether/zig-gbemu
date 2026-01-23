const std = @import("std");

const GBContext = @import("gbcontext.zig");

const rl = @import("raylib");
const argsParser = @import("args");

const CYCLES_PER_FRAME = 70224;
const SECONDE_PER_CYCLE = 0.0000002384;

const OPCODE_NAME = @import("opcode.zig").OPCODE_NAME;
const OPCODE_LEN = @import("opcode.zig").OPCODE_LEN;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const options = try argsParser.parseForCurrentProcess(struct {
        file: ?[]const u8 = null,
        step: bool = false,
        @"skip-rom-step": bool = false,

        pub const shorthands = .{
            .s = "step",
            .f = "file",
            .S = "skip-rom-step",
        };
    }, allocator, .print);
    defer options.deinit();

    const boot_rom = try std.fs.cwd().readFileAlloc(allocator, "cgb_boot.bin", std.math.maxInt(usize));
    defer allocator.free(boot_rom);

    if (options.options.file == null) {
        std.log.err("format: {?s} --file=filename", .{options.executable_name});
        return;
    }

    const rom = try std.fs.cwd().readFileAlloc(allocator, options.options.file.?, std.math.maxInt(usize));
    defer allocator.free(rom);

    var context = GBContext{
        .allocator = allocator,
        .boot_rom = boot_rom,
    };
    try context.set_rom(rom);
    defer context.deinit();

    context.init_bios();

    rl.initWindow(160 * 4, 144 * 4, "GBEmu");
    rl.setExitKey(.null);
    defer rl.closeWindow();

    const image = rl.Image{
        .data = &context.ppu.framebuffer,
        .width = 160,
        .height = 144,
        .mipmaps = 1,
        .format = .uncompressed_r8g8b8a8,
    };

    const texture = try rl.Texture.fromImage(image);
    defer texture.unload();
    // rl.setTextureFilter(texture, .);

    var skip_next_halt = false;

    while (true) {
        var timer = try std.time.Timer.start();
        var cycles_this_frame: u64 = 0;

        rl.beginDrawing();
        rl.updateTexture(texture, &context.ppu.framebuffer);
        texture.drawPro(
            .{ .x = 0, .y = 0, .width = 160, .height = 144 },
            .{ .x = 0, .y = 0, .width = 160 * 4, .height = 144 * 4 },
            .{ .x = 0, .y = 0 },
            0,
            .white,
        );

        rl.endDrawing();

        var skip_next_frame = false;

        while (cycles_this_frame < CYCLES_PER_FRAME) {
            if (rl.windowShouldClose()) return;

            if (@import("builtin").mode == .Debug) {
                if (options.options.step) {
                    if (!(options.options.@"skip-rom-step" and context.io.boot_rom_mapped)) {
                        while (true and !skip_next_frame) {
                            skip_next_frame = false;
                            skip_next_halt = false;
                            rl.pollInputEvents();
                            if (rl.windowShouldClose()) return;
                            if (rl.isKeyPressed(.enter)) break;
                            if (rl.isKeyPressed(.v)) skip_next_frame = true;
                            if (rl.isKeyDown(.space)) break;
                            rl.waitTime(0.01);
                        }
                        std.debug.print("-----    -----\n\n", .{});
                    }
                }
            }

            if (context.read_bus(context.pc.read()) == 0x40) {
                while (true) {
                    rl.pollInputEvents();
                    if (rl.windowShouldClose()) return;
                    if (rl.isKeyPressed(.enter)) break;
                }
            }

            check_key(&context);

            const old_ppu_mode = context.ppu.status.ppu_mode;

            const old_tick = context.ticks;
            context.step();
            const mult: u8 = if (context.io.speed.read_bit(7)) 2 else 4;

            cycles_this_frame += (context.ticks - old_tick) * mult;

            const new_ppu_mode = context.ppu.status.ppu_mode;

            if (old_ppu_mode != new_ppu_mode and new_ppu_mode == .VBLANK) break;

            rl.pollInputEvents();
        }

        if (timer.read() < 16_742_706) {
            std.Thread.sleep(16_742_706 - timer.read());
        }
    }
}

fn check_key(context: *GBContext) void {
    const old_interrupt_state = context.io.dpad != 0xf or context.io.button != 0xf;

    context.io.dpad = 0xf;
    context.io.button = 0xf;

    const right = rl.isKeyDown(.right);
    const left = rl.isKeyDown(.left);
    const up = rl.isKeyDown(.up);
    const down = rl.isKeyDown(.down);

    if (right and !left) context.io.dpad &= 0b1110;
    if (left and !right) context.io.dpad &= 0b1101;
    if (up and !down) context.io.dpad &= 0b1011;
    if (down and !up) context.io.dpad &= 0b0111;

    if (rl.isKeyDown(.a)) context.io.button &= 0b1110;
    if (rl.isKeyDown(.s)) context.io.button &= 0b1101;
    if (rl.isKeyDown(.escape)) context.io.button &= 0b1011;
    if (rl.isKeyDown(.left_alt)) context.io.button &= 0b0111;

    const new_interrupt_state = context.io.dpad != 0xf or context.io.button != 0xf;

    if (new_interrupt_state and !old_interrupt_state) {
        context.request_interrupt(.joypad);
        context.stopped = false;
    }
}
