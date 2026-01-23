const std = @import("std");

const IoRegister = @import("structure/io_register.zig");

dpad: u4 = 0xf,
button: u4 = 0xf,

legacy_mode: IoRegister = .init(true, 0b00000100, 0b00000100, 0),
speed: IoRegister = .init(true, 0b10000001, 1, 0),

pub fn get(self: *@This(), addr: u16) *IoRegister {
    return switch (addr) {
        0xFF4C => &self.legacy_mode,
        0xFF4D => &self.speed,
        else => std.debug.panic("unexpected read @ 0x{X:0>4}", .{addr}),
    };
}
