const std = @import("std");

const MBC1 = @import("mbc1.zig");
const MBC3 = @import("mbc3.zig");
const MBC5 = @import("mbc5.zig");

const Mapper = @This();

const Type = enum { NoMapper, MBC1, MBC3, MBC5 };

rom: []u8 = undefined,
ram: []u8 = undefined,
// true si la cartouche a une battery (RAM à persister en .sav).
has_battery: bool = false,
// true dès qu'un byte de RAM a été écrit (main.zig flush le .sav et clear).
dirty: bool = false,
// Horloge hôte pour la RTC MBC3 (posée par main, .real). Null = pas d'horloge.
host_io: ?std.Io = null,
// true dès qu'un registre RTC a été écrit (main.zig flush le .rtc et clear).
rtc_dirty: bool = false,
// Override de l'horloge en ns (tests uniquement). Prioritaire sur host_io.
test_clock_ns: ?i128 = null,
mapper: union(Type) {
    NoMapper: void,
    MBC1: MBC1,
    MBC3: MBC3,
    MBC5: MBC5,
} = .NoMapper,

/// Heure hôte actuelle en ns (wall-clock .real), ou l'override de test, ou 0.
pub fn host_now_ns(self: *const Mapper) i128 {
    if (self.test_clock_ns) |t| return t;
    if (self.host_io) |io| {
        const ts = std.Io.Timestamp.now(io, .real);
        return @as(i128, ts.nanoseconds);
    }
    return 0;
}

pub inline fn read_bus(self: *Mapper, addr: u16) u8 {
    return switch (self.mapper) {
        .NoMapper => self.rom[addr % self.rom.len],
        .MBC1 => self.mapper.MBC1.read(self, addr),
        .MBC3 => self.mapper.MBC3.read(self, addr),
        .MBC5 => self.mapper.MBC5.read(self, addr),
    };
}

pub inline fn write_bus(self: *Mapper, addr: u16, value: u8) void {
    switch (self.mapper) {
        .NoMapper => {}, //No writing allowed
        .MBC1 => self.mapper.MBC1.write(self, addr, value),
        .MBC3 => self.mapper.MBC3.write(self, addr, value),
        .MBC5 => self.mapper.MBC5.write(self, addr, value),
    }
}

pub inline fn deinit(self: *Mapper, allocator: std.mem.Allocator) void {
    allocator.free(self.ram);
}
