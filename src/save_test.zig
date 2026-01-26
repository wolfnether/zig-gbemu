const std = @import("std");
const GBContext = @import("gbcontext.zig");
const main = @import("main.zig");
const Cartrige = @import("cartrige.zig");

fn fake_rom(allocator: std.mem.Allocator, cart_type: u8, ram_size: u8) ![]u8 {
    const rom = try allocator.alloc(u8, 0x150);
    @memset(rom, 0);
    rom[0x0147] = cart_type;
    rom[0x0149] = ram_size;
    return rom;
}

test "save: chemin .sav" {
    const allocator = std.testing.allocator;
    const a = try main.save_path_for_rom(allocator, "Pokemon Blue.gb");
    defer allocator.free(a);
    try std.testing.expectEqualStrings("Pokemon Blue.sav", a);

    const b = try main.save_path_for_rom(allocator, "dir/jeu.sans.ext.gb");
    defer allocator.free(b);
    try std.testing.expectEqualStrings("dir/jeu.sans.ext.sav", b);

    const c = try main.save_path_for_rom(allocator, "sansext");
    defer allocator.free(c);
    try std.testing.expectEqualStrings("sansext.sav", c);
}

test "save: detection battery + RAM à 0xFF" {
    const allocator = std.testing.allocator;
    // Zelda-like: MBC1+BATTERY, 8KB.
    const rom = try fake_rom(allocator, 0x03, 0x02);
    defer allocator.free(rom);
    var mapper = Cartrige.Mapper{ .rom = rom };
    try Cartrige.init_cartrige(allocator, &mapper);
    defer mapper.deinit(allocator);

    try std.testing.expect(mapper.has_battery);
    try std.testing.expectEqual(@as(usize, 0x2000), mapper.ram.len);
    for (mapper.ram) |byte| try std.testing.expectEqual(@as(u8, 0xFF), byte);
}

test "save: jeu sans RAM ne crash pas au deinit" {
    const allocator = std.testing.allocator;
    // Mario Land-like: MBC1, pas de RAM.
    const rom = try fake_rom(allocator, 0x01, 0x00);
    defer allocator.free(rom);
    var mapper = Cartrige.Mapper{ .rom = rom };
    try Cartrige.init_cartrige(allocator, &mapper);
    defer mapper.deinit(allocator); // free d'un slice vide = safe

    try std.testing.expect(!mapper.has_battery);
    try std.testing.expectEqual(@as(usize, 0), mapper.ram.len);
    // Lecture/écriture sans RAM -> 0xFF, pas de crash, pas de dirty.
    try std.testing.expectEqual(@as(u8, 0xFF), mapper.read_bus(0xA000));
    mapper.write_bus(0x0000, 0x0A); // RAM enable
    mapper.write_bus(0xA000, 0x42);
    try std.testing.expect(!mapper.dirty);
}

test "save: type 0x10 (MBC3+TIMER+RAM+BATTERY, Or/Argent/Cristal)" {
    const allocator = std.testing.allocator;
    const rom = try fake_rom(allocator, 0x10, 0x03);
    defer allocator.free(rom);
    var mapper = Cartrige.Mapper{ .rom = rom };
    try Cartrige.init_cartrige(allocator, &mapper);
    defer mapper.deinit(allocator);

    try std.testing.expect(mapper.has_battery);
    try std.testing.expectEqual(@as(usize, 0x8000), mapper.ram.len);
    switch (mapper.mapper) {
        .MBC3 => {},
        else => return error.TestUnexpectedResult,
    }
    // RTC utilisable : write/latch/read sans RAM allouée... ici avec RAM.
    mapper.test_clock_ns = 3_000_000_000_000;
    mapper.write_bus(0x0000, 0x0A);
    mapper.write_bus(0x4000, 0x0B); // DL
    mapper.write_bus(0xA000, 0x2A);
    mapper.write_bus(0x6000, 0x00);
    mapper.write_bus(0x6000, 0x01);
    try std.testing.expectEqual(@as(u8, 0x2A), mapper.read_bus(0xA000));
}

test "save: write RAM pose dirty" {
    const allocator = std.testing.allocator;
    // Blue-like: MBC3+BATTERY, 32KB.
    const rom = try fake_rom(allocator, 0x13, 0x03);
    defer allocator.free(rom);
    var mapper = Cartrige.Mapper{ .rom = rom };
    try Cartrige.init_cartrige(allocator, &mapper);
    defer mapper.deinit(allocator);

    try std.testing.expect(mapper.has_battery);
    try std.testing.expect(!mapper.dirty);
    mapper.write_bus(0x0000, 0x0A); // RAM enable
    mapper.write_bus(0xA000, 0x42);
    try std.testing.expect(mapper.dirty);
    try std.testing.expectEqual(@as(u8, 0x42), mapper.read_bus(0xA000));
}

test "save: round-trip fichier" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init_single_threaded;
    const io = threaded.io();

    const rom = try fake_rom(allocator, 0x1B, 0x03); // Jaune-like: MBC5, 32KB
    defer allocator.free(rom);
    var empty_rom: [0]u8 = .{};
    var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };
    ctx.mapper.rom = rom;
    try Cartrige.init_cartrige(allocator, &ctx.mapper);
    defer ctx.mapper.deinit(allocator);

    const path = "/tmp/opencode/gbemu_save_test.sav";
    ctx.mapper.write_bus(0x0000, 0x0A);
    ctx.mapper.write_bus(0xA000, 0xAB);
    ctx.mapper.write_bus(0xBFFF, 0xCD);
    main.flush_save(io, path, &ctx);
    try std.testing.expect(!ctx.mapper.dirty);

    // Recharge dans une RAM razée et compare tout (fond à 0xFF d'origine).
    @memset(ctx.mapper.ram, 0);
    main.load_save(io, path, &ctx);
    try std.testing.expectEqual(@as(u8, 0xAB), ctx.mapper.ram[0]);
    try std.testing.expectEqual(@as(u8, 0xCD), ctx.mapper.ram[0x1FFF]);
    for (ctx.mapper.ram[1..0x1FFF]) |byte| try std.testing.expectEqual(@as(u8, 0xFF), byte);
}
