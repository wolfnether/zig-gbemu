const std = @import("std");
const GBContext = @import("gbcontext.zig");

// GDMA de 2 blocs (32 octets) WRAM -> VRAM : tout doit arriver,
// et FF55 doit signaler la fin (bit7=1).
test "hdma gdma multi-blocs" {
    const allocator = std.testing.allocator;
    var empty_rom: [0]u8 = .{};
    var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };

    for (0..32) |i| ctx.wram[0][i] = @truncate(i * 3 + 7);
    for (0..32) |i| ctx.ppu.vram[0][i] = 0;

    ctx.io.write(&ctx, 0xFF51, 0xC0); // src = 0xC000
    ctx.io.write(&ctx, 0xFF52, 0x00);
    ctx.io.write(&ctx, 0xFF53, 0x80); // dst = 0x8000
    ctx.io.write(&ctx, 0xFF54, 0x00);
    ctx.io.write(&ctx, 0xFF55, 0x01); // GDMA, len=1 -> 2 blocs

    try std.testing.expect(ctx.hdma.started);
    try std.testing.expect(!ctx.hdma.status.hblank);

    // 2 octets/tick -> 16 ticks pour 32 octets, on large.
    for (0..24) |_| ctx.hdma.tick(&ctx);

    for (0..32) |i| {
        try std.testing.expectEqual(@as(u8, @truncate(i * 3 + 7)), ctx.ppu.vram[0][i]);
    }
    try std.testing.expect(!ctx.hdma.started);
    try std.testing.expectEqual(@as(u8, 0xFF), ctx.hdma.read_status());
}

// Le bit7 de FF55 sélectionne le mode, les bits0-6 la longueur.
test "hdma decode mode et longueur" {
    const allocator = std.testing.allocator;
    var empty_rom: [0]u8 = .{};
    var ctx = GBContext{ .allocator = allocator, .boot_rom = &empty_rom };

    ctx.io.write(&ctx, 0xFF51, 0xC0);
    ctx.io.write(&ctx, 0xFF52, 0x00);
    ctx.io.write(&ctx, 0xFF53, 0x80);
    ctx.io.write(&ctx, 0xFF54, 0x00);
    ctx.io.write(&ctx, 0xFF55, 0x8F); // HBLANK, len=0x0F (16 blocs)

    try std.testing.expect(ctx.hdma.status.hblank);
    try std.testing.expectEqual(@as(u7, 0x0F), ctx.hdma.status.len);
    // Transfert actif -> bit7 de FF55 à 0.
    try std.testing.expectEqual(@as(u8, 0x0F), ctx.io.read(&ctx, 0xFF55));

    // Abort : écriture mode GDMA pendant un transfert HBLANK actif.
    ctx.io.write(&ctx, 0xFF55, 0x00);
    try std.testing.expect(!ctx.hdma.started);
}
