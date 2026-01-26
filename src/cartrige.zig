const std = @import("std");

pub const Mapper = @import("cardride/mapper.zig");

pub fn init_cartrige(allocator: std.mem.Allocator, mapper: *Mapper) !void {
    switch (mapper.rom[0x0147]) {
        0x00 => {},
        0x01...0x03 => mapper.mapper = .{ .MBC1 = .{} },
        0x11...0x13 => mapper.mapper = .{ .MBC3 = .{} },
        0x19...0x1E => mapper.mapper = .{ .MBC5 = .{} },
        else => |i| std.debug.panic("uniplemented cartrige type 0x{X:0>2}", .{i}),
    }

    const ram_size: u6 = switch (mapper.rom[0x0149]) {
        0x00, 0x01 => 0,
        0x02 => 1,
        0x03 => 4,
        0x04 => 16,
        0x05 => 8,
        else => |i| std.debug.panic("uniplemented cartrige ram size 0x{X:0>2}", .{i}),
    };

    if (ram_size != 0) {
        mapper.ram = try allocator.alloc(u8, @as(usize, 0x2000) << (ram_size - 1));
    }
}
