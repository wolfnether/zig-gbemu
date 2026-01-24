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
TAC: IoRegister = .init(false, 0b111, 0b111, 0),
joypad: IoRegister = .init(false, 0, 0b110000, 0),

stat: IoRegister = .init(true, 0xff, 0b1111000, 0),

void_reg: IoRegister = .init(false, 0, 0, 0),

legacy_mode: bool = false,

pub fn read(self: *@This(), context: *GBContext, addr: u16) u8 {
    return switch (addr) {
        0xFF00 => {
            const sel = self.joypad.read_bits(4, 5);
            var result: u4 = 0xF;
            if (sel & 1 == 0) result &= self.dpad;
            if (sel & 2 == 0) result &= self.button;
            return result | (sel << 4) | 0xC0;
        },
        0xFF02 => 0b10000000,
        0xFF04 => context.timer.internal_DIV.bytes.h,
        0xFF0F => self.interrupt_flag.read(self.legacy_mode),
        0xFF40 => @bitCast(context.ppu.control),
        0xFF41 => @bitCast(context.ppu.status),
        0xFF42 => context.ppu.scx,
        0xFF44 => context.ppu.ly,
        0xFF70 => self.wbank.read(self.legacy_mode),
        0xFFFF => self.interrupt_enable.read(self.legacy_mode),
        else => std.debug.panic("unexpected read @ 0x{X:0>4}", .{addr}),
    };
}

pub fn write(self: *@This(), context: *GBContext, addr: u16, value: u8) void {
    switch (addr) {
        0xFF00 => self.joypad.write(self.legacy_mode, value),
        0xFF0F => self.interrupt_flag.write(self.legacy_mode, value),
        0xFF01 => std.debug.print("{c}", .{value}),
        0xFF02 => {},
        0xFF07 => {
            self.TAC.write(self.legacy_mode, value);
            context.timer.set_TAC(context, @truncate(self.TAC.value));
        },
        0xFF10...0xFF26 => self.void_reg.write(self.legacy_mode, value),
        0xFF30...0xFF3F => self.void_reg.write(self.legacy_mode, value),
        0xFF40 => context.ppu.control = @bitCast(value),
        0xFF41 => {
            self.stat.value = @bitCast(context.ppu.status);
            self.stat.write(self.legacy_mode, value);
            context.ppu.status = @bitCast(self.stat.value);
        },
        0xFF42 => context.ppu.scy = value,
        0xFF43 => context.ppu.scx = value,
        0xFF45 => context.ppu.lyc = value,
        0xFF46 => context.dma.start(@bitCast(value)),
        0xFF47 => context.ppu.bgp = @bitCast(value),
        0xFF48 => context.ppu.obp0 = @bitCast(value),
        0xFF49 => context.ppu.obp1 = @bitCast(value),
        0xFF4A => context.ppu.wy = value,
        0xFF4B => context.ppu.wx = value,
        0xFF4C => if (self.boot_rom_mapped) {
            self.legacy_mode = value & 4 != 0;
        },
        0xFF4F => self.vbank.write(self.legacy_mode, value),
        0xFF50 => if (self.boot_rom_mapped) {
            self.boot_rom_mapped = false;
        },
        0xFF51 => context.hdma.src.bytes.h = value,
        0xFF52 => context.hdma.src.bytes.l = value,
        0xFF53 => context.hdma.dst.bytes.h = value,
        0xFF54 => context.hdma.dst.bytes.l = value,
        0xFF55 => context.hdma.set_status(@bitCast(value)),
        0xFF68 => self.bcps.write(self.legacy_mode, value),
        0xFF69 => {
            const index = self.bcps.read_bits(0, 5);
            context.ppu.write_background_palette(index, value);
            if (self.bcps.read_bit(7)) {
                self.bcps.write_bits(0, 5, index +% 1);
            }
        },
        0xFF6A => self.ocps.write(self.legacy_mode, value),
        0xFF6B => {
            const index = self.ocps.read_bits(0, 5);
            context.ppu.write_object_palette(index, value);
            if (self.ocps.read_bit(7)) {
                self.ocps.write_bits(0, 5, index +% 1);
            }
        },
        0xFF6C => context.ppu.priority_mode = value & 1 == 1,
        0xFF70 => self.wbank.write(self.legacy_mode, value),
        0xFFFF => self.interrupt_enable.write(self.legacy_mode, value),
        else => std.debug.panic("unexpected write @ 0x{X:0>4}", .{addr}),
    }
}
