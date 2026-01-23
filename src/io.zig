const std = @import("std");

const IoRegister = @import("structure/io_register.zig");
const GBContext = @import("gbcontext.zig");

boot_rom_mapped: bool = true,

dpad: u4 = 0xf,
button: u4 = 0xf,

interrupt_enable: IoRegister = .init(false, 0b11111, 0b11111, 0),
interrupt_flag: IoRegister = .init(false, 0b11111, 0b11111, 0),
speed: IoRegister = .init(true, 0b10000001, 1, 0),
wbank: IoRegister = .init(true, 0b111, 0b111, 1),
vbank: IoRegister = .init(true, 1, 1, 0),
bcps: IoRegister = .init(true, 0b10111111, 0b10111111, 0),
ocps: IoRegister = .init(true, 0b10111111, 0b10111111, 0),

void_reg: IoRegister = .init(false, 0, 0, 0),

legacy_mode: bool = false,

pub fn read(self: *@This(), addr: u16) u8 {
    return switch (addr) {
        0xFF0F => self.interrupt_flag,
        0xFF70 => self.wbank,
        0xFFFF => self.interrupt_enable,
        else => std.debug.panic("unexpected read @ 0x{X:0>4}", .{addr}),
    }.read(self.legacy_mode);
}

pub fn write(self: *@This(), context: *GBContext, addr: u16, value: u8) void {
    switch (addr) {
        0xFF0F => self.interrupt_flag.write(self.legacy_mode, value),
        0xFF10...0xFF26 => self.void_reg.write(self.legacy_mode, value),
        0xFF30...0xFF3F => self.void_reg.write(self.legacy_mode, value),
        0xFF40 => context.ppu.control = @bitCast(value),
        0xFF47 => context.ppu.bgp = @bitCast(value),
        0xFF4C => if (self.boot_rom_mapped) {
            self.legacy_mode = value & 4 != 0;
        },
        0xFF4F => self.vbank.write(self.legacy_mode, value),
        0xFF50 => if (self.boot_rom_mapped) {
            self.boot_rom_mapped = true;
        },
        0xFF51 => context.hdma.src.bytes.h = value,
        0xFF52 => context.hdma.src.bytes.l = value,
        0xFF53 => context.hdma.dst.bytes.h = value,
        0xFF54 => context.hdma.dst.bytes.l = value,
        0xFF55 => context.hdma.set_statue(@bitCast(value)),
        0xFF68 => self.bcps.write(self.legacy_mode, value),
        0xFF69 => {
            const index = self.bcps.read_bits(0, 5);
            context.ppu.write_background_palette(index, value);
            if (self.bcps.read_bit(7)) {
                self.bcps.write_bits(0, 5, value +% 1);
            }
        },
        0xFF6A => self.ocps.write(self.legacy_mode, value),
        0xFF6B => {
            const index = self.ocps.read_bits(0, 5);
            context.ppu.write_object_palette(index, value);
            if (self.ocps.read_bit(7)) {
                self.ocps.write_bits(0, 5, value +% 1);
            }
        },

        0xFF70 => self.wbank.write(self.legacy_mode, value),
        else => std.debug.panic("unexpected write @ 0x{X:0>4}", .{addr}),
    }
}
