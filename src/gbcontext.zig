const std = @import("std");

const Cardrige = @import("cartrige.zig");
const Register = @import("structure/register.zig").Register;

const GbContext = @This();

const InterruptType = enum(u3) { vblank = 0, lcd = 1, timer = 2, serial = 3, joypad = 4 };

allocator: std.mem.Allocator,
boot_rom: []u8,
time: usize = 0,

stopped: bool = false,

mapper: Cardrige.Mapper = .{},

ppu: @import("ppu.zig") = .{},
io: @import("io.zig") = .{},

boot_rom_mapped: bool = true,

wram: [8][0x1000]u8 = undefined,

pc: Register = .init(0),

pub fn request_interrupt(self: *@This(), interrupt_type: InterruptType) void {
    const bit: u3 = @intFromEnum(interrupt_type);
    self.io.get(0xFFFF).write_bit(bit, true);
}

pub fn set_rom(self: *GbContext, rom: []u8) !void {
    self.mapper.rom = rom;
    try Cardrige.init_cartrige(self.allocator, &self.mapper);
}

pub fn init_bios(_: *GbContext) void {}

pub fn deinit(self: *GbContext) void {
    self.mapper.deinit(self.allocator);
}

pub fn step(_: *GbContext) void {
    @panic("TODO: step");
}

pub fn read_bus(_: *GbContext, _: u16) u8 {
    @panic("TODO: read_bus");
}
