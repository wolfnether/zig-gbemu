const std = @import("std");

const Mapper = @import("mapper.zig");

const RomAddress = packed struct(u32) {
    _0: u14,
    _1: u5,
    _2: u2,
    _: u11 = 0,
};
const RamAddress = packed struct(u16) {
    _0: u13,
    _1: u2,
    _: u1 = 0,
};

mode: bool = false,

ram_enabled: bool = false,

bank1: u5 = 0,
bank2: u2 = 0,

pub fn read(self: *@This(), mapper: *Mapper, addr: u16) u8 {
    switch (addr) {
        0x0000...0x3FFF => {
            const address = RomAddress{
                ._0 = @truncate(addr),
                ._1 = 0,
                ._2 = if (self.mode) self.bank2 else 0,
            };

            const comp_addr: u32 = @bitCast(address);
            const mod_addr = comp_addr & (mapper.rom.len - 1);
            return mapper.rom[mod_addr];
        },
        0x4000...0x7FFF => {
            const address = RomAddress{
                ._0 = @truncate(addr),
                ._1 = if (self.bank1 != 0) self.bank1 else 1,
                ._2 = self.bank2,
            };

            const comp_addr: u32 = @bitCast(address);
            const mod_addr = comp_addr & (mapper.rom.len - 1);
            return mapper.rom[mod_addr];
        },
        0xA000...0xBFFF => {
            if (!self.ram_enabled) return 0xff;
            if (mapper.ram.len == 0) return 0xff;
            const address = RamAddress{
                ._0 = @truncate(addr),
                ._1 = if (self.mode) self.bank2 else 0,
            };
            const comp_addr: u16 = @bitCast(address);
            const mod_addr = comp_addr % mapper.ram.len;
            return mapper.ram[mod_addr];
        },
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    }
}

pub fn write(self: *@This(), mapper: *Mapper, addr: u16, value: u8) void {
    switch (addr) {
        0x0000...0x1FFF => self.ram_enabled = value & 0x0F == 0x0A,
        0x2000...0x3FFF => self.bank1 = @truncate(value),
        0x4000...0x5FFF => self.bank2 = @truncate(value),
        0x6000...0x7FFF => self.mode = (value & 1) == 1,
        0xA000...0xBFFF => {
            if (!self.ram_enabled) return;
            const address = RamAddress{
                ._0 = @truncate(addr),
                ._1 = if (self.mode) self.bank2 else 0,
            };
            const comp_addr: u16 = @bitCast(address);
            if (mapper.ram.len != 0) {
                const mod_addr = comp_addr % mapper.ram.len;
                mapper.ram[mod_addr] = value;
                mapper.dirty = true;
            }
        },
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    }
}
