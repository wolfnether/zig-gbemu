const std = @import("std");
const GBContext = @import("gbcontext.zig");
const main = @import("main.zig");
const Cartrige = @import("cartrige.zig");

const MBC3_ROM = 0x11; // MBC3, pas de RAM (RTC seule)

fn rtc_mapper(allocator: std.mem.Allocator) !Cartrige.Mapper {
    const rom = try allocator.alloc(u8, 0x150);
    @memset(rom, 0);
    rom[0x0147] = MBC3_ROM;
    rom[0x0149] = 0x00;
    var mapper = Cartrige.Mapper{ .rom = rom };
    try Cartrige.init_cartrige(allocator, &mapper);
    // RAM enable + sélection banque RTC par défaut.
    mapper.write_bus(0x0000, 0x0A);
    return mapper;
}

fn free_mapper(allocator: std.mem.Allocator, mapper: *Cartrige.Mapper) void {
    allocator.free(mapper.rom);
    mapper.deinit(allocator);
}

fn write_reg(mapper: *Cartrige.Mapper, idx: u8, value: u8) void {
    mapper.write_bus(0x4000, 0x08 + idx);
    mapper.write_bus(0xA000, value);
}

fn latch(mapper: *Cartrige.Mapper) void {
    mapper.write_bus(0x6000, 0x00);
    mapper.write_bus(0x6000, 0x01);
}

fn read_reg(mapper: *Cartrige.Mapper, idx: u8) u8 {
    mapper.write_bus(0x4000, 0x08 + idx);
    return mapper.read_bus(0xA000);
}

test "rtc: write/latch/read" {
    const allocator = std.testing.allocator;
    var mapper = try rtc_mapper(allocator);
    defer free_mapper(allocator, &mapper);
    mapper.test_clock_ns = 1_000_000_000_000;

    write_reg(&mapper, 0, 30);
    write_reg(&mapper, 1, 15);
    write_reg(&mapper, 2, 10);
    write_reg(&mapper, 3, 5);
    write_reg(&mapper, 4, 0x00);
    try std.testing.expect(mapper.rtc_dirty);

    latch(&mapper);
    try std.testing.expectEqual(@as(u8, 30), read_reg(&mapper, 0));
    try std.testing.expectEqual(@as(u8, 15), read_reg(&mapper, 1));
    try std.testing.expectEqual(@as(u8, 10), read_reg(&mapper, 2));
    try std.testing.expectEqual(@as(u8, 5), read_reg(&mapper, 3));
    try std.testing.expectEqual(@as(u8, 0x00), read_reg(&mapper, 4));
}

test "rtc: le temps s'écoule (90s)" {
    const allocator = std.testing.allocator;
    var mapper = try rtc_mapper(allocator);
    defer free_mapper(allocator, &mapper);
    mapper.test_clock_ns = 1_000_000_000_000;

    write_reg(&mapper, 0, 30);
    write_reg(&mapper, 1, 15);
    write_reg(&mapper, 2, 10);
    write_reg(&mapper, 3, 5);
    write_reg(&mapper, 4, 0x00);

    mapper.test_clock_ns.? += 90 * 1_000_000_000;
    latch(&mapper);
    // 30s + 90s = 120s -> S=0, M=17.
    try std.testing.expectEqual(@as(u8, 0), read_reg(&mapper, 0));
    try std.testing.expectEqual(@as(u8, 17), read_reg(&mapper, 1));
    try std.testing.expectEqual(@as(u8, 10), read_reg(&mapper, 2));
    try std.testing.expectEqual(@as(u8, 5), read_reg(&mapper, 3));
}

test "rtc: halt fige, unhalt reprend" {
    const allocator = std.testing.allocator;
    var mapper = try rtc_mapper(allocator);
    defer free_mapper(allocator, &mapper);
    mapper.test_clock_ns = 1_000_000_000_000;

    write_reg(&mapper, 0, 0);
    write_reg(&mapper, 1, 0);
    write_reg(&mapper, 2, 0);
    write_reg(&mapper, 3, 0);
    write_reg(&mapper, 4, 0x40); // halt

    mapper.test_clock_ns.? += 3600 * 1_000_000_000;
    latch(&mapper);
    try std.testing.expectEqual(@as(u8, 0), read_reg(&mapper, 0));
    try std.testing.expectEqual(@as(u8, 0), read_reg(&mapper, 1));

    write_reg(&mapper, 4, 0x00); // unhalt
    mapper.test_clock_ns.? += 61 * 1_000_000_000;
    latch(&mapper);
    try std.testing.expectEqual(@as(u8, 1), read_reg(&mapper, 0));
    try std.testing.expectEqual(@as(u8, 1), read_reg(&mapper, 1));
}

test "rtc: overflow jour -> carry + wrap" {
    const allocator = std.testing.allocator;
    var mapper = try rtc_mapper(allocator);
    defer free_mapper(allocator, &mapper);
    mapper.test_clock_ns = 1_000_000_000_000;

    write_reg(&mapper, 0, 0);
    write_reg(&mapper, 1, 0);
    write_reg(&mapper, 2, 0);
    write_reg(&mapper, 3, 255);
    write_reg(&mapper, 4, 0x01); // jour bit8 -> jour 511

    mapper.test_clock_ns.? += 2 * 86400 * 1_000_000_000; // +2 jours -> 513
    latch(&mapper);
    try std.testing.expectEqual(@as(u8, 1), read_reg(&mapper, 3)); // 513 % 512
    // DH = carry(0x80) | bit8 du jour affiché (1 -> 0).
    try std.testing.expectEqual(@as(u8, 0x80), read_reg(&mapper, 4));
}

test "rtc: serialize round-trip" {
    const allocator = std.testing.allocator;
    var mapper = try rtc_mapper(allocator);
    defer free_mapper(allocator, &mapper);
    mapper.test_clock_ns = 5_000_000_000_000;

    write_reg(&mapper, 2, 23);
    write_reg(&mapper, 3, 100);
    const blob = mapper.mapper.MBC3.rtc_serialize();

    var mapper2 = try rtc_mapper(allocator);
    defer free_mapper(allocator, &mapper2);
    mapper2.test_clock_ns = mapper.test_clock_ns;
    try std.testing.expect(mapper2.mapper.MBC3.rtc_deserialize(&blob) == true);
    // Même heure lue des deux côtés.
    const a = mapper.mapper.MBC3.current_regs(&mapper);
    const b = mapper2.mapper.MBC3.current_regs(&mapper2);
    try std.testing.expectEqual(a, b);
    // Mauvais magic -> false.
    var bad = blob;
    bad[0] = 'X';
    try std.testing.expect(mapper2.mapper.MBC3.rtc_deserialize(&bad) == false);
}

test "rtc: le temps passe émulateur éteint" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init_single_threaded;
    const io = threaded.io();
    const path = "/tmp/opencode/gbemu_rtc_off_test.rtc";
    const T0: i128 = 9_000_000_000_000;

    // Session 1 : horloge réglée à 0, flush, "fermeture".
    {
        var empty_rom: [0]u8 = .{};
        var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };
        const rom = try allocator.alloc(u8, 0x150);
        @memset(rom, 0);
        rom[0x0147] = MBC3_ROM;
        defer allocator.free(rom);
        ctx.mapper.rom = rom;
        try Cartrige.init_cartrige(allocator, &ctx.mapper);
        defer ctx.mapper.deinit(allocator);
        ctx.mapper.test_clock_ns = T0;

        ctx.mapper.write_bus(0x0000, 0x0A);
        ctx.mapper.write_bus(0x4000, 0x08);
        ctx.mapper.write_bus(0xA000, 0x00); // S=0 (M/H/J déjà 0)
        main.flush_rtc(io, path, &ctx);
        try std.testing.expect(!ctx.mapper.rtc_dirty);
    }

    // Session 2 : 1h02m03s plus tard, recharge -> l'horloge a avancé.
    {
        var empty_rom: [0]u8 = .{};
        var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };
        const rom = try allocator.alloc(u8, 0x150);
        @memset(rom, 0);
        rom[0x0147] = MBC3_ROM;
        defer allocator.free(rom);
        ctx.mapper.rom = rom;
        try Cartrige.init_cartrige(allocator, &ctx.mapper);
        defer ctx.mapper.deinit(allocator);
        ctx.mapper.test_clock_ns = T0 + 3723 * 1_000_000_000;

        main.load_rtc(io, path, &ctx);
        ctx.mapper.write_bus(0x0000, 0x0A);
        ctx.mapper.write_bus(0x6000, 0x00);
        ctx.mapper.write_bus(0x6000, 0x01);
        ctx.mapper.write_bus(0x4000, 0x08);
        try std.testing.expectEqual(@as(u8, 3), ctx.mapper.read_bus(0xA000));
        ctx.mapper.write_bus(0x4000, 0x09);
        try std.testing.expectEqual(@as(u8, 2), ctx.mapper.read_bus(0xA000));
        ctx.mapper.write_bus(0x4000, 0x0A);
        try std.testing.expectEqual(@as(u8, 1), ctx.mapper.read_bus(0xA000));
    }
}

test "rtc: round-trip fichier .rtc" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init_single_threaded;
    const io = threaded.io();

    var empty_rom: [0]u8 = .{};
    var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };
    const rom = try allocator.alloc(u8, 0x150);
    @memset(rom, 0);
    rom[0x0147] = MBC3_ROM;
    defer allocator.free(rom);
    ctx.mapper.rom = rom;
    try Cartrige.init_cartrige(allocator, &ctx.mapper);
    defer ctx.mapper.deinit(allocator);
    ctx.mapper.test_clock_ns = 2_000_000_000_000;

    const path = "/tmp/opencode/gbemu_rtc_test.rtc";
    ctx.mapper.write_bus(0x0000, 0x0A);
    ctx.mapper.write_bus(0x4000, 0x0A); // H
    ctx.mapper.write_bus(0xA000, 0x07);
    ctx.mapper.write_bus(0x4000, 0x0B); // DL
    ctx.mapper.write_bus(0xA000, 0x2A);
    main.flush_rtc(io, path, &ctx);
    try std.testing.expect(!ctx.mapper.rtc_dirty);

    // Reset complet puis recharge.
    ctx.mapper.mapper.MBC3.rtc_base = .{0} ** 5;
    ctx.mapper.mapper.MBC3.rtc_host_base_ns = null;
    main.load_rtc(io, path, &ctx);

    ctx.mapper.write_bus(0x6000, 0x00);
    ctx.mapper.write_bus(0x6000, 0x01);
    ctx.mapper.write_bus(0x4000, 0x0A);
    try std.testing.expectEqual(@as(u8, 0x07), ctx.mapper.read_bus(0xA000));
    ctx.mapper.write_bus(0x4000, 0x0B);
    try std.testing.expectEqual(@as(u8, 0x2A), ctx.mapper.read_bus(0xA000));
}
