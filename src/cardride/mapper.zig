const std = @import("std");

const MBC1 = @import("mbc1.zig");
const MBC5 = @import("mbc1.zig");

const Mapper = @This();

const Type = enum { NoMapper, MBC1, MBC5 };

rom: []u8 = undefined,
ram: []u8 = undefined,
mapper: union(Type) {
    NoMapper: void,
    MBC1: MBC1,
    MBC5: MBC5,
} = .NoMapper,

pub inline fn read_bus(self: *Mapper, addr: u16) u8 {
    return switch (self.mapper) {
        .NoMapper => self.rom[addr],
        .MBC1 => self.mapper.MBC1.read(self, addr),
        .MBC5 => self.mapper.MBC5.read(self, addr),
    };
}

pub inline fn write_bus(self: *Mapper, addr: u16, value: u8) void {
    switch (self.mapper) {
        .NoMapper => {}, //No writing allowed
        .MBC1 => self.mapper.MBC1.write(self, addr, value),
        .MBC5 => self.mapper.MBC5.write(self, addr, value),
    }
}

pub inline fn deinit(self: *Mapper, allocator: std.mem.Allocator) void {
    allocator.free(self.ram);
}
