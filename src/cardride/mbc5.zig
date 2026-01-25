const std = @import("std");

const Mapper = @import("mapper.zig");

const RomAddress = packed struct(u32) {
    _0: u14,
    _1: u8,
    _2: u1,
    _: u9 = 0,
};
const RamAddress = packed struct(u32) {
    _0: u13,
    _1: u4,
    _: u15 = 0,
};

rom_bank1: u8 = 1,
rom_bank2: u1 = 0,
ram_bank: u4 = 0,
ram_enabled: bool = false,

pub fn read(self: *@This(), mapper: *Mapper, addr: u16) u8 {
    return switch (addr) {
        0x0000...0x3FFF => mapper.rom[addr],
        0x4000...0x7FFF => {
            const address = RomAddress{
                ._0 = @truncate(addr),
                ._1 = self.rom_bank1,
                ._2 = self.rom_bank2,
            };
            const comp_addr: u32 = @bitCast(address);
            const mod_addr = comp_addr % mapper.rom.len;
            return mapper.rom[mod_addr];
        },
        0xA000...0xBFFF => {
            if (!self.ram_enabled) return 0xFF;
            const address = RamAddress{
                ._0 = @truncate(addr),
                ._1 = self.ram_bank,
            };
            const comp_addr: u32 = @bitCast(address);
            const mod_addr = comp_addr % mapper.ram.len;
            return mapper.ram[mod_addr];
        },
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    };
}

pub fn write(self: *@This(), mapper: *Mapper, addr: u16, value: u8) void {
    switch (addr) {
        0x0000...0x1FFF => self.ram_enabled = value == 0x0A,
        0x2000...0x2FFF => self.rom_bank1 = value,
        0x3000...0x3FFF => self.rom_bank2 = @truncate(value),
        0x4000...0x5FFF => self.ram_bank = @truncate(value),
        0x6000...0x9FFF => {},
        0xA000...0xBFFF => {
            if (!self.ram_enabled) return;
            const address = RamAddress{
                ._0 = @truncate(addr),
                ._1 = self.ram_bank,
            };
            const comp_addr: u32 = @bitCast(address);
            const mod_addr = comp_addr % mapper.ram.len;
            mapper.ram[mod_addr] = value;
        },
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    }
}
