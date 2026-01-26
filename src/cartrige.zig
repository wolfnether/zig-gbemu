const std = @import("std");

pub const Mapper = @import("cardride/mapper.zig");

pub fn init_cartrige(allocator: std.mem.Allocator, mapper: *Mapper) !void {
    switch (mapper.rom[0x0147]) {
        0x00, 0x08, 0x09 => {}, // Pas de mapper (RAM éventuelle gérée via ram_size)
        0x01...0x03 => mapper.mapper = .{ .MBC1 = .{} },
        0x0F...0x13 => mapper.mapper = .{ .MBC3 = .{} }, // 0x0F/0x10 = +TIMER
        0x19...0x1E => mapper.mapper = .{ .MBC5 = .{} },
        else => |i| std.debug.panic("uniplemented cartrige type 0x{X:0>2}", .{i}),
    }

    // Header 0x149 : seules 0x00-0x05 existent dans la spec.
    // Max réel : 128KB (MBC5, 16 banques). Les valeurs inconnues (hackroms
    // exotiques) ne plantent plus : warning + pas de RAM plutôt que panic.
    const ram_banks: u6 = switch (mapper.rom[0x0149]) {
        0x00 => 0,
        0x01 => 1, // 2KB annoncés : on alloue la banque 8KB (miroir/compat)
        0x02 => 1, // 8KB
        0x03 => 4, // 32KB
        0x04 => 16, // 128KB (max spec, MBC5)
        0x05 => 8, // 64KB
        else => |i| blk: {
            std.log.warn("cartrige: taille RAM inconnue 0x{X:0>2}, pas de RAM", .{i});
            break :blk 0;
        },
    };

    if (ram_banks != 0) {
        mapper.ram = try allocator.alloc(u8, @as(usize, 0x2000) * ram_banks);
        // SRAM vierge = 0xFF (comme une cartouche neuve).
        @memset(mapper.ram, 0xFF);
    } else {
        // Slice vide alloué (et non undefined) pour un deinit/free safe.
        mapper.ram = try allocator.alloc(u8, 0);
    }

    mapper.has_battery = switch (mapper.rom[0x0147]) {
        0x03, 0x06, 0x09, 0x0D, 0x0F, 0x10, 0x13, 0x1B, 0x1E => true,
        else => false,
    };
}
