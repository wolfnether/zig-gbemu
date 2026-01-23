const std = @import("std");

const MBC1 = @import("mbc1.zig");
const MBC5 = @import("mbc1.zig");

const Mapper = @This();

const Type = enum { NoMapper, MBC1, MBC5 };

mapper_type: Type = .NoMapper,
rom: []u8 = undefined,
ram: []u8 = undefined,

const MBC0RomAddress = packed struct(u32) {
    _0: u14,
    _1: u5,
    _2: u2,
    _: u11 = 0,
};
const MBC0RamAddress = packed struct(u16) {
    _0: u13,
    _1: u2,
    _: u1 = 0,
};
const MBC5RomAddress = packed struct(u32) {
    _0: u14,
    _1: u8,
    _2: bool,
    _: u9 = 0,
};

pub inline fn read_bus(self: *Mapper, addr: usize) u8 {
    return switch (self.mapper_type) {
        .NoMapper => self.rom[addr],
        .MBC1 => MBC1.read_bus(self.rom, self.ram, addr),
        .MBC5 => MBC5.read_bus(self.rom, self.ram, addr),
    };
}

pub inline fn write_bus(self: *Mapper, addr: u16, value: u8) void {
    switch (self.mapper_type) {
        .NoMapper => {}, //No writing allowed
        .MBC1 => MBC1.write_bus(self.rom, self.ram, addr, value),
        .MBC5 => MBC5.write_bus(self.rom, self.ram, addr, value),
    }
}

pub inline fn deinit(self: *Mapper, allocator: std.mem.Allocator) void {
    allocator.free(self.ram);
}
