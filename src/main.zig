const std = @import("std");

const GBContext = @import("gbcontext.zig");

const rl = @import("raylib");
const argsParser = @import("args");

const CYCLES_PER_FRAME = 70224;
const SECONDE_PER_CYCLE = 0.0000002384;
const FRAME_SECONDS: f64 = 16_742_706.0 / 1_000_000_000.0; // ~59.73 Hz

const OPCODE_NAME = @import("opcode.zig").OPCODE_NAME;
const OPCODE_LEN = @import("opcode.zig").OPCODE_LEN;

const TCYCLES_PER_SAMPLE = @import("apu.zig").TCYCLES_PER_SAMPLE;

pub const AudioQueue = struct {
    const BUFFER_SIZE = 8192;

    data: [BUFFER_SIZE]f32 = undefined,
    write_ptr: u13 = 0,
    read_ptr: u13 = 0,

    pub fn get_available(self: *const AudioQueue) usize {
        if (self.write_ptr >= self.read_ptr) {
            return self.write_ptr - self.read_ptr;
        }
        return BUFFER_SIZE - @as(usize, self.read_ptr - self.write_ptr);
    }

    pub fn push_sample(self: *AudioQueue, l: f32, r: f32) void {
        self.data[self.write_ptr] = l;
        self.data[self.write_ptr + 1] = r;
        self.write_ptr +%= 2;
    }

    pub fn fill_buffer(self: *AudioQueue, output_ptr: [*]f32, frames: usize) void {
        if (self.get_available() < frames * 2) {
            for (0..frames * 2) |i| {
                output_ptr[i] = 0.0;
            }
            return;
        }
        for (0..frames * 2) |i| {
            output_ptr[i] = self.data[self.read_ptr];
            self.read_ptr +%= 1;
        }
    }
};

var audio_queue = AudioQueue{};

fn feed_the_beast(ptr: ?*anyopaque, frames: c_uint) callconv(.c) void {
    const cast: [*]f32 = @ptrCast(@alignCast(ptr));
    audio_queue.fill_buffer(cast, frames);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const options = try argsParser.parseForCurrentProcess(struct {
        file: ?[]const u8 = null,
        step: bool = false,
        breakpoint: bool = false,
        @"skip-rom-step": bool = false,
        @"no-sleep": bool = false,
        @"debug-print": bool = false,

        pub const shorthands = .{
            .s = "step",
            .f = "file",
            .S = "skip-rom-step",
            .b = "breakpoint",
            .F = "no-sleep",
            .D = "debug-print",
        };
    }, init, .print);
    defer options.deinit();

    const boot_rom = try std.Io.Dir.cwd().readFileAlloc(init.io, "cgb_boot.bin", allocator, .unlimited);
    defer allocator.free(boot_rom);

    if (options.options.file == null) {
        std.log.err("format: {?s} --file=filename", .{options.executable_name});
        return;
    }

    const rom = try std.Io.Dir.cwd().readFileAlloc(init.io, options.options.file.?, allocator, .unlimited);
    defer allocator.free(rom);

    var context = GBContext{
        .allocator = allocator,
        .boot_rom = boot_rom,
        .debug_print = options.options.@"debug-print",
    };
    try context.set_rom(rom);
    defer context.deinit();
    context.mapper.host_io = init.io;

    // Save: <rom>.sav à côté de la ROM (format brut, compatible autres émus).
    const save_path = try save_path_for_rom(allocator, options.options.file.?);
    defer allocator.free(save_path);
    load_save(init.io, save_path, &context);
    defer flush_save(init.io, save_path, &context);

    // RTC MBC3: <rom>.rtc séparé (le .sav reste brut et compatible).
    const rtc_path = try rtc_path_for_rom(allocator, options.options.file.?);
    defer allocator.free(rtc_path);
    load_rtc(init.io, rtc_path, &context);
    defer flush_rtc(init.io, rtc_path, &context);

    context.init_bios();

    rl.initWindow(160 * 4, 144 * 4, "GBEmu");
    rl.setExitKey(.null);
    rl.setTargetFPS(144);
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
    rl.setTextureFilter(texture, .anisotropic_16x);

    var skip_next_halt = false;

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    const audio_stream = try rl.loadAudioStream(44100, 32, 2);
    defer audio_stream.unload();

    rl.setAudioStreamCallback(audio_stream, &feed_the_beast);

    rl.setAudioStreamPan(audio_stream, 0.5);
    rl.setAudioStreamPitch(audio_stream, 1.0);
    rl.setAudioStreamVolume(audio_stream, 0.5);

    var sample_timer: f32 = 0;

    rl.playAudioStream(audio_stream);

    var next_frame_time: f64 = rl.getTime();

    while (true) {
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

        //for (1..144) |i| {
        //    rl.drawLine(0, @intCast(i * 4), 160 * 4, @intCast(i * 4), .gray);
        //}
        //
        //for (1..160) |i| {
        //    rl.drawLine(@intCast(i * 4), 0, @intCast(i * 4), 144 * 4, .gray);
        //}

        rl.endDrawing();
        if (rl.windowShouldClose()) return;

        var skip_next_frame = false;

        while (cycles_this_frame < CYCLES_PER_FRAME) {
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

            if (context.read_bus_internal(context.pc.read(), false) == 0x40 and options.options.breakpoint) {
                rl.beginDrawing();
                rl.drawText("Breakpoint", 0, 0, 32, .gray);
                rl.endDrawing();
                while (true) {
                    rl.pollInputEvents();
                    if (rl.windowShouldClose()) return;
                    if (rl.isKeyPressed(.enter)) break;
                    rl.waitTime(0.01);
                }
            }

            const old_ppu_mode = context.ppu.status.ppu_mode;

            const old_tick = context.ticks;
            context.step();
            const mult: u8 = if (context.io.speed.read_bit(7)) 2 else 4;

            const delta_tick = (context.ticks - old_tick) * mult;

            cycles_this_frame += delta_tick;
            sample_timer += @floatFromInt(delta_tick);

            const new_ppu_mode = context.ppu.status.ppu_mode;

            if (sample_timer >= TCYCLES_PER_SAMPLE) {
                sample_timer -= TCYCLES_PER_SAMPLE;

                const samples = context.apu.read_sample();
                context.apu.reset_sample();
                audio_queue.push_sample(samples[0], samples[1]);
            }

            if (old_ppu_mode == .VBLANK and new_ppu_mode != .VBLANK) {
                rl.pollInputEvents();
                if (rl.windowShouldClose()) return;
                check_key(&context);
                break;
            }
        }
        //if (rl.isAudioStreamProcessed(audio_stream) and ) {
        //    const frame: i32 = @intCast(i / 2);
        //    const max_frame = @min(frame, 1024);
        //    const rem = 2048 - i;
        //    break;
        //}

        next_frame_time += FRAME_SECONDS;
        const now = rl.getTime();
        const sleep_s = next_frame_time - now;

        if (sleep_s > 0 and !options.options.@"no-sleep") {
            rl.waitTime(sleep_s);
        } else if (sleep_s < -FRAME_SECONDS * 5) {
            next_frame_time = now;
        }

        // Flush la save en continu (perte max = 1 frame en cas de crash).
        if (context.mapper.dirty) flush_save(init.io, save_path, &context);
        if (context.mapper.rtc_dirty) flush_rtc(init.io, rtc_path, &context);
    }
}

/// Chemin d'un fichier annexe : même nom que la ROM, extension donnée.
fn path_with_ext(allocator: std.mem.Allocator, rom_path: []const u8, ext: []const u8) ![]u8 {
    const dot = std.mem.lastIndexOfScalar(u8, rom_path, '.');
    const base = if (dot) |i| rom_path[0..i] else rom_path;
    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ base, ext });
}

/// Chemin de la save : même nom que la ROM, extension .sav.
pub fn save_path_for_rom(allocator: std.mem.Allocator, rom_path: []const u8) ![]u8 {
    return path_with_ext(allocator, rom_path, "sav");
}

/// Chemin de la RTC : même nom que la ROM, extension .rtc.
pub fn rtc_path_for_rom(allocator: std.mem.Allocator, rom_path: []const u8) ![]u8 {
    return path_with_ext(allocator, rom_path, "rtc");
}

/// Charge le .sav dans la SRAM (si battery + taille exacte), sinon SRAM à 0xFF.
pub fn load_save(io: std.Io, save_path: []const u8, context: *GBContext) void {
    if (!context.mapper.has_battery or context.mapper.ram.len == 0) return;
    const data = std.Io.Dir.cwd().readFileAlloc(io, save_path, context.allocator, .unlimited) catch |err| {
        if (err != error.FileNotFound) std.log.warn("save: lecture {s} impossible: {}", .{ save_path, err });
        return;
    };
    defer context.allocator.free(data);
    if (data.len != context.mapper.ram.len) {
        std.log.warn("save: taille inattendue {s} ({} != {}), ignorée", .{ save_path, data.len, context.mapper.ram.len });
        return;
    }
    @memcpy(context.mapper.ram, data);
    std.log.info("save: {s} chargée ({} octets)", .{ save_path, data.len });
}

/// Écrit la SRAM dans le .sav si dirty (puis clear). Jamais de crash sur erreur FS.
pub fn flush_save(io: std.Io, save_path: []const u8, context: *GBContext) void {
    if (!context.mapper.has_battery or context.mapper.ram.len == 0) return;
    if (!context.mapper.dirty) return;
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = save_path, .data = context.mapper.ram }) catch |err| {
        std.log.warn("save: écriture {s} impossible: {}", .{ save_path, err });
        return;
    };
    context.mapper.dirty = false;
}

/// Charge le .rtc (MBC3 uniquement). Ignoré si absent/invalide.
pub fn load_rtc(io: std.Io, rtc_path: []const u8, context: *GBContext) void {
    const mbc3 = switch (context.mapper.mapper) {
        .MBC3 => |*m| m,
        else => return,
    };
    const data = std.Io.Dir.cwd().readFileAlloc(io, rtc_path, context.allocator, .unlimited) catch |err| {
        if (err != error.FileNotFound) std.log.warn("rtc: lecture {s} impossible: {}", .{ rtc_path, err });
        return;
    };
    defer context.allocator.free(data);
    if (!mbc3.rtc_deserialize(data)) {
        std.log.warn("rtc: {s} invalide, ignoré", .{rtc_path});
        return;
    }
    context.mapper.rtc_dirty = false;
    std.log.info("rtc: {s} chargée", .{rtc_path});
}

/// Écrit l'état RTC dans le .rtc si modifié (puis clear).
pub fn flush_rtc(io: std.Io, rtc_path: []const u8, context: *GBContext) void {
    const mbc3 = switch (context.mapper.mapper) {
        .MBC3 => |*m| m,
        else => return,
    };
    if (!context.mapper.rtc_dirty) return;
    const blob = mbc3.rtc_serialize();
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = rtc_path, .data = &blob }) catch |err| {
        std.log.warn("rtc: écriture {s} impossible: {}", .{ rtc_path, err });
        return;
    };
    context.mapper.rtc_dirty = false;
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
