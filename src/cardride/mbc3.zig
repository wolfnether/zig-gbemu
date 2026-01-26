const std = @import("std");

const Register = @import("../gbcontext.zig").Register;
const Mapper = @import("mapper.zig");

const RomAddress = packed struct(u32) {
    _0: u14,
    _1: u8,
    _: u10 = 0,
};
const RamAddress = packed struct(u32) {
    _0: u13,
    _1: u8,
    _: u11 = 0,
};

const RTC = struct {
    rtc_s: u8 = 0,
    rtc_m: u8 = 0,
    rtc_h: u8 = 0,
    rtc_d: Register = .init(0),
};

mode: bool = false,

ram_enabled: bool = false,

rom_bank: u8 = 0,
ram_bank: u8 = 0,

rtc: RTC = .{},
latched_rtc: RTC = .{},
latching_rtc: bool = false,

pub fn read(self: *@This(), mapper: *Mapper, addr: u16) u8 {
    return switch (addr) {
        0x0000...0x3FFF => mapper.rom[addr],
        0x4000...0x7FFF => {
            const address = RomAddress{
                ._0 = @truncate(addr),
                ._1 = if (self.rom_bank != 0) self.rom_bank else 1,
            };

            const comp_addr: u32 = @bitCast(address);
            const mod_addr = comp_addr & (mapper.rom.len - 1);
            return mapper.rom[mod_addr];
        },
        0xA000...0xBFFF => {
            if (!self.ram_enabled) return 0xFF;

            if (0x00 <= self.ram_bank and self.ram_bank <= 0x07) {
                const address = RamAddress{
                    ._0 = @truncate(addr),
                    ._1 = self.ram_bank,
                };
                const comp_addr: u32 = @bitCast(address);
                const mod_addr = comp_addr % mapper.ram.len;
                return mapper.ram[mod_addr];
            } else if (0x08 <= self.ram_bank and self.ram_bank <= 0x0F) {
                @panic("todo");
            }
            return 0xFF;
        },
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    };
}

pub fn write(self: *@This(), mapper: *Mapper, addr: u16, value: u8) void {
    switch (addr) {
        0x0000...0x1FFF => self.ram_enabled = value == 0x0A,
        0x2000...0x3FFF => self.rom_bank = @truncate(value),
        0x4000...0x5FFF => {
            self.ram_bank = value;
        },
        0x6000...0x7FFF => {
            if (value == 0x00) {
                self.latching_rtc = true;
            } else if (value == 0x01 and self.latching_rtc) {
                self.latching_rtc = false;
                self.latched_rtc = self.rtc;
            } else {
                self.latching_rtc = false;
            }
        },
        0xA000...0xBFFF => {
            if (!self.ram_enabled) return;

            if (0x00 <= self.ram_bank and self.ram_bank <= 0x07) {
                const address = RamAddress{
                    ._0 = @truncate(addr),
                    ._1 = self.ram_bank,
                };
                const comp_addr: u32 = @bitCast(address);
                const mod_addr = comp_addr % mapper.ram.len;
                mapper.ram[mod_addr] = value;
            } else if (0x08 <= self.ram_bank and self.ram_bank <= 0x0F) {
                @panic("todo");
            }
        },
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    }
}
