const std = @import("std");
const GBContext = @import("gbcontext.zig");

comptime {
    _ = @import("hdma_test.zig");
    _ = @import("save_test.zig");
    _ = @import("rtc_test.zig");
}

// Drive l'APU par les vrais writes IO (comme un jeu) puis échantillonne
// comme main.zig. Détecte un APU qui reste muet.
test "ch1 square frequence correcte (440Hz)" {
    const allocator = std.testing.allocator;
    var empty_rom: [0]u8 = .{};
    var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };

    ctx.io.write(&ctx, 0xFF26, 0x80);
    ctx.io.write(&ctx, 0xFF10, 0x00);
    ctx.io.write(&ctx, 0xFF11, 0x40); // duty 1 (25%)
    ctx.io.write(&ctx, 0xFF12, 0xF0); // vol 15 fixe
    ctx.io.write(&ctx, 0xFF13, 0xD6);
    ctx.io.write(&ctx, 0xFF14, 0x86); // trigger 440Hz, pas de length

    // Compte les fronts montants de la sortie DAC sur N M-cycles.
    // Attendu: 1 front par cycle de 8*298 = 2384 M-cycles.
    const N: usize = 200_000;
    var crossings: usize = 0;
    var prev: f32 = ctx.apu.ch1.dac_output();
    var t: usize = 0;
    while (t < N) : (t += 1) {
        ctx.timer.tick(&ctx);
        ctx.apu.tick(&ctx);
        const cur = ctx.apu.ch1.dac_output();
        if (prev <= 0 and cur > 0) crossings += 1;
        prev = cur;
    }
    const freq = @as(f32, @floatFromInt(crossings)) * 1048576.0 / @as(f32, @floatFromInt(N));
    std.debug.print("ch1 freq={d}Hz (crossings={d})\n", .{ freq, crossings });
    // 440Hz attendu: 200000/2384 ~= 84 fronts.
    try std.testing.expect(crossings >= 80 and crossings <= 88);
}

test "ch1 square 440Hz audible" {
    const allocator = std.testing.allocator;
    var empty_rom: [0]u8 = .{};
    var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };

    // Power on explicite (comme un jeu).
    ctx.io.write(&ctx, 0xFF26, 0x80);
    try std.testing.expect(ctx.io.nr52.read_bit(7));

    // NR10: pas de sweep.
    ctx.io.write(&ctx, 0xFF10, 0x00);
    // NR11: duty 1 (25%), length 0.
    ctx.io.write(&ctx, 0xFF11, 0x40);
    // NR12: volume 15, pas d'enveloppe (period 0).
    ctx.io.write(&ctx, 0xFF12, 0xF0);
    // 440 Hz -> period = 2048 - 131072/440 ~= 0x6D6.
    ctx.io.write(&ctx, 0xFF13, 0xD6);
    // Trigger (bit 7), length désactivée (bit 6 = 0), freq high = 0x6.
    ctx.io.write(&ctx, 0xFF14, 0x86);

    // Le trigger doit allumer le status NR52.0.
    try std.testing.expect(ctx.io.nr52.read_bit(0));
    try std.testing.expect(ctx.apu.ch1.enabled);

    // Laisse tourner timer + APU (~50 frames), échantillonne comme main.zig.
    var max_abs: f32 = 0;
    var sample_timer: f32 = 0;
    const TCYCLES_PER_SAMPLE: f32 = 4194304.0 / 44100.0;
    var t: usize = 0;
    while (t < 200_000) : (t += 1) {
        ctx.timer.tick(&ctx);
        ctx.apu.tick(&ctx);
        sample_timer += 4; // 1 M-cycle = 4 T-cycles
        if (sample_timer >= TCYCLES_PER_SAMPLE) {
            sample_timer -= TCYCLES_PER_SAMPLE;
            const s = ctx.apu.read_sample();
            ctx.apu.reset_sample();
            max_abs = @max(max_abs, @abs(s[0]));
            max_abs = @max(max_abs, @abs(s[1]));
        }
    }
    std.debug.print("ch1 max_abs={d}\n", .{max_abs});
    try std.testing.expect(max_abs > 0.01);
}

test "ch2 square audible" {
    const allocator = std.testing.allocator;
    var empty_rom: [0]u8 = .{};
    var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };

    ctx.io.write(&ctx, 0xFF26, 0x80);
    ctx.io.write(&ctx, 0xFF16, 0x40);
    ctx.io.write(&ctx, 0xFF17, 0xF0);
    ctx.io.write(&ctx, 0xFF18, 0xD6);
    ctx.io.write(&ctx, 0xFF19, 0x86);

    try std.testing.expect(ctx.io.nr52.read_bit(1));

    var max_abs: f32 = 0;
    var sample_timer: f32 = 0;
    const TCYCLES_PER_SAMPLE: f32 = 4194304.0 / 44100.0;
    var t: usize = 0;
    while (t < 200_000) : (t += 1) {
        ctx.timer.tick(&ctx);
        ctx.apu.tick(&ctx);
        sample_timer += 4;
        if (sample_timer >= TCYCLES_PER_SAMPLE) {
            sample_timer -= TCYCLES_PER_SAMPLE;
            const s = ctx.apu.read_sample();
            ctx.apu.reset_sample();
            max_abs = @max(max_abs, @abs(s[0]));
            max_abs = @max(max_abs, @abs(s[1]));
        }
    }
    std.debug.print("ch2 max_abs={d}\n", .{max_abs});
    try std.testing.expect(max_abs > 0.01);
}

test "ch4 noise audible" {
    const allocator = std.testing.allocator;
    var empty_rom: [0]u8 = .{};
    var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };

    ctx.io.write(&ctx, 0xFF26, 0x80);
    ctx.io.write(&ctx, 0xFF20, 0x3F);
    ctx.io.write(&ctx, 0xFF21, 0xF0);
    ctx.io.write(&ctx, 0xFF22, 0x20); // mid clock
    ctx.io.write(&ctx, 0xFF23, 0x80); // trigger, pas de length

    try std.testing.expect(ctx.io.nr52.read_bit(3));

    var max_abs: f32 = 0;
    var sample_timer: f32 = 0;
    const TCYCLES_PER_SAMPLE: f32 = 4194304.0 / 44100.0;
    var t: usize = 0;
    while (t < 200_000) : (t += 1) {
        ctx.timer.tick(&ctx);
        ctx.apu.tick(&ctx);
        sample_timer += 4;
        if (sample_timer >= TCYCLES_PER_SAMPLE) {
            sample_timer -= TCYCLES_PER_SAMPLE;
            const s = ctx.apu.read_sample();
            ctx.apu.reset_sample();
            max_abs = @max(max_abs, @abs(s[0]));
            max_abs = @max(max_abs, @abs(s[1]));
        }
    }
    std.debug.print("ch4 max_abs={d}\n", .{max_abs});
    try std.testing.expect(max_abs > 0.01);
}
