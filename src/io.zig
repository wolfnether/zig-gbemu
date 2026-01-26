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

undoc1: IoRegister = .init(false, 0xff, 0xff, 0),
undoc2: IoRegister = .init(false, 0xff, 0xff, 0),
undoc3: IoRegister = .init(false, 0xff, 0xff, 0),
undoc4: IoRegister = .init(false, 0b01110000, 0b01110000, 0),

unused: IoRegister = .init(false, 0b10000001, 0b10000001, 0b10000001),

stat: IoRegister = .init(false, 0x7f, 0b1111000, 0),

void_reg: IoRegister = .init(false, 0, 0, 0),

legacy_mode: bool = false,

nr10: IoRegister = .init(false, 0x7f, 0x7f, 0x80),
nr11: IoRegister = .init(false, 0xff, 0b11000000, 0xBF),
nr12: IoRegister = .init(false, 0xff, 0xff, 0xF3),
nr13: IoRegister = .init(false, 0, 0xff, 0xFF),
nr14: IoRegister = .init(false, 0xff, 0b11000000, 0xBF),
nr21: IoRegister = .init(false, 0xff, 0xff, 0x3F),
nr22: IoRegister = .init(false, 0xff, 0xff, 0x00),
nr23: IoRegister = .init(false, 0xff, 0xff, 0xFF),
nr24: IoRegister = .init(false, 0xff, 0xff, 0xBF),
nr30: IoRegister = .init(false, 0x80, 0x80, 0x7F),
nr31: IoRegister = .init(false, 0xff, 0xff, 0xFF),
nr32: IoRegister = .init(false, 0b1100000, 0b1100000, 0x9F),
nr33: IoRegister = .init(false, 0xff, 0xff, 0xFF),
nr34: IoRegister = .init(false, 0xff, 0xff, 0xBF),
nr41: IoRegister = .init(false, 0b111111, 0b111111, 0xFF),
nr42: IoRegister = .init(false, 0xff, 0xff, 0x00),
nr43: IoRegister = .init(false, 0xff, 0xff, 0x00),
nr44: IoRegister = .init(false, 0b01000000, 0b11000000, 0xBF),
nr50: IoRegister = .init(false, 0xff, 0xff, 0x77),
nr51: IoRegister = .init(false, 0xff, 0xff, 0xF3),
nr52: IoRegister = .init(false, 0b10001111, 0b10000000, 0xF1),

pub fn read(self: *@This(), context: *GBContext, addr: u16) u8 {
    return switch (addr) {
        0xFF00 => {
            const sel = self.joypad.read_bits(4, 5);
            var result: u4 = 0xF;
            if (sel & 1 == 0) result &= self.dpad;
            if (sel & 2 == 0) result &= self.button;
            return (sel << 4) | result;
        },
        0xFF02 => self.unused.read(self.legacy_mode),
        0xFF03 => 0xFF,
        0xFF04 => context.timer.internal_DIV.bytes.h,
        0xFF05 => context.timer.TIMA,
        0xFF06 => context.timer.TMA,
        0xFF07 => self.TAC.read(self.legacy_mode),
        0xFF08...0xFF0E => 0xFF,
        0xFF10 => self.nr10.read(self.legacy_mode),
        0xFF11 => self.nr11.read(self.legacy_mode),
        0xFF12 => self.nr12.read(self.legacy_mode),
        0xFF13 => self.nr13.read(self.legacy_mode),
        0xFF14 => self.nr14.read(self.legacy_mode),
        0xFF15 => 0xFF,
        0xFF16 => self.nr21.read(self.legacy_mode),
        0xFF17 => self.nr22.read(self.legacy_mode),
        0xFF18 => self.nr23.read(self.legacy_mode),
        0xFF19 => self.nr24.read(self.legacy_mode),
        0xFF1A => self.nr30.read(self.legacy_mode),
        0xFF1B => self.nr31.read(self.legacy_mode),
        0xFF1C => self.nr32.read(self.legacy_mode),
        0xFF1D => self.nr33.read(self.legacy_mode),
        0xFF1E => self.nr34.read(self.legacy_mode),
        0xFF1F => 0xFF,
        0xFF20 => self.nr41.read(self.legacy_mode),
        0xFF21 => self.nr42.read(self.legacy_mode),
        0xFF22 => self.nr43.read(self.legacy_mode),
        0xFF23 => self.nr44.read(self.legacy_mode),
        0xFF24 => self.nr50.read(self.legacy_mode),
        0xFF25 => self.nr51.read(self.legacy_mode),
        0xFF26 => self.nr52.read(self.legacy_mode),
        0xFF27...0xFF3F => 0xFF,
        0xFF0F => self.interrupt_flag.read(self.legacy_mode),
        0xFF40 => @bitCast(context.ppu.control),
        0xFF41 => @bitCast(context.ppu.status),
        0xFF42 => context.ppu.scy,
        0xFF43 => context.ppu.scx,
        0xFF44 => context.ppu.ly,
        0xFF45 => context.ppu.lyc,
        0xFF46 => context.dma.new_source_page,
        0xFF47 => @bitCast(context.ppu.bgp),
        0xFF48 => @bitCast(context.ppu.obp0),
        0xFF49 => @bitCast(context.ppu.obp1),
        0xFF4C => if (self.legacy_mode) 0xff else 0b11111011,
        0xFF4D => self.speed.read(self.legacy_mode),
        0xFF4E => 0xFF,
        0xFF4F => self.vbank.read(self.legacy_mode),
        0xFF50 => 0xFF,
        0xFF51...0xFF54 => 0xFF,
        0xFF55 => if (!self.legacy_mode) context.hdma.status.len else 0xff,
        0xFF56...0xFF67 => 0xFF,
        0xFF68 => self.bcps.read(self.legacy_mode),
        0xFF69 => if (self.legacy_mode) 0xff else @panic("0xFF69 !legacy_mode not implemented"),
        0xFF6A => self.ocps.read(self.legacy_mode),
        0xFF6B => if (self.legacy_mode) 0xff else @panic("0xFF6B !legacy_mode ot implemented"),
        0xFF6C...0xFF6F => 0xFF,
        0xFF70 => self.wbank.read(self.legacy_mode),
        0xFF71 => 0xFF,
        0xFF72 => self.undoc1.read(self.legacy_mode),
        0xFF73 => self.undoc2.read(self.legacy_mode),
        0xFF74 => self.undoc3.read(self.legacy_mode),
        0xFF75 => self.undoc4.read(self.legacy_mode),
        0xFF76...0xFF7F => 0xFF,
        0xFFFF => self.interrupt_enable.value,
        else => std.debug.panic("unexpected read @ 0x{X:0>4}", .{addr}),
    };
}

pub fn write(self: *@This(), context: *GBContext, addr: u16, value: u8) void {
    switch (addr) {
        0xFF00 => self.joypad.write(self.legacy_mode, value),
        0xFF01 => std.debug.print("{c}", .{value}),
        0xFF02 => self.unused.write(self.legacy_mode, value),
        0xFF03 => {},
        0xFF04 => context.timer.set_DIV(context, 0),
        0xFF05 => context.timer.TIMA = value,
        0xFF06 => context.timer.TMA = value,
        0xFF07 => {
            self.TAC.write(self.legacy_mode, value);
            context.timer.set_TAC(context, @truncate(self.TAC.value));
        },
        0xFF08...0xFF0E => {},
        0xFF0F => self.interrupt_flag.write(self.legacy_mode, value),
        0xFF10 => self.nr10.write(self.legacy_mode, value),
        0xFF11 => self.nr11.write(self.legacy_mode, value),
        0xFF12 => self.nr12.write(self.legacy_mode, value),
        0xFF13 => self.nr13.write(self.legacy_mode, value),
        0xFF14 => self.nr14.write(self.legacy_mode, value),
        0xFF15 => {},
        0xFF16 => self.nr21.write(self.legacy_mode, value),
        0xFF17 => self.nr22.write(self.legacy_mode, value),
        0xFF18 => self.nr23.write(self.legacy_mode, value),
        0xFF19 => self.nr24.write(self.legacy_mode, value),
        0xFF1A => self.nr30.write(self.legacy_mode, value),
        0xFF1B => self.nr31.write(self.legacy_mode, value),
        0xFF1C => self.nr32.write(self.legacy_mode, value),
        0xFF1D => self.nr33.write(self.legacy_mode, value),
        0xFF1E => self.nr34.write(self.legacy_mode, value),
        0xFF1F => {},
        0xFF20 => self.nr41.write(self.legacy_mode, value),
        0xFF21 => self.nr42.write(self.legacy_mode, value),
        0xFF22 => self.nr43.write(self.legacy_mode, value),
        0xFF23 => self.nr44.write(self.legacy_mode, value),
        0xFF24 => self.nr50.write(self.legacy_mode, value),
        0xFF25 => self.nr51.write(self.legacy_mode, value),
        0xFF26 => self.nr52.write(self.legacy_mode, value),
        0xFF27...0xFF3F => {},
        0xFF40 => {
            const old_control = context.ppu.control;
            context.ppu.control = @bitCast(value);
            if (context.ppu.control.enable and !old_control.enable) {
                context.ppu.skip_frame = true;
            }
        },
        0xFF41 => {
            const old_stat_irq = context.ppu.stat_irq_line;

            self.stat.value = @bitCast(context.ppu.status);
            self.stat.write(self.legacy_mode, value);
            context.ppu.status = @bitCast(self.stat.read(self.legacy_mode));

            const mode_irq = switch (context.ppu.status.ppu_mode) {
                .HBLANK => context.ppu.status.mode_0_int,
                .VBLANK => context.ppu.status.mode_1_int,
                .OAM_SCAN => context.ppu.status.mode_2_int,
                .DRAW => false,
            };
            const lyc_irq = context.ppu.status.lyc_int and context.ppu.status.lyc_eq_ly;
            context.ppu.stat_irq_line = mode_irq or lyc_irq;

            if (context.ppu.stat_irq_line and !old_stat_irq) {
                context.request_interrupt(.stat);
            }
        },
        0xFF42 => context.ppu.scy = value,
        0xFF43 => context.ppu.scx = value,
        0xFF45 => {
            const old_stat_irq = context.ppu.stat_irq_line;

            context.ppu.lyc = value;
            context.ppu.status.lyc_eq_ly = context.ppu.ly == context.ppu.lyc;

            const mode_irq = switch (context.ppu.status.ppu_mode) {
                .HBLANK => context.ppu.status.mode_0_int,
                .VBLANK => context.ppu.status.mode_1_int,
                .OAM_SCAN => context.ppu.status.mode_2_int,
                .DRAW => false,
            };
            const lyc_irq = context.ppu.status.lyc_int and context.ppu.status.lyc_eq_ly;
            context.ppu.stat_irq_line = mode_irq or lyc_irq;

            if (context.ppu.stat_irq_line and !old_stat_irq) {
                context.request_interrupt(.stat);
            }
        },
        0xFF46 => context.dma.start(@bitCast(value)),
        0xFF47 => context.ppu.bgp = @bitCast(value),
        0xFF48 => context.ppu.obp0 = @bitCast(value),
        0xFF49 => context.ppu.obp1 = @bitCast(value),
        0xFF4A => context.ppu.wy = value,
        0xFF4B => context.ppu.wx = value,
        0xFF4C => if (self.boot_rom_mapped) {
            self.legacy_mode = value & 4 != 0;
        },
        0xFF4D => self.speed.write(self.legacy_mode, value),
        0xFF4E => {},
        0xFF4F => self.vbank.write(self.legacy_mode, value),
        0xFF50 => if (self.boot_rom_mapped) {
            self.boot_rom_mapped = false;
        },
        0xFF51 => context.hdma.src.bytes.h = value,
        0xFF52 => context.hdma.src.bytes.l = value,
        0xFF53 => context.hdma.dst.bytes.h = value,
        0xFF54 => context.hdma.dst.bytes.l = value,
        0xFF55 => if (!self.legacy_mode) {
            context.hdma.set_status(@bitCast(value));
        },
        0xFF56...0xFF67 => {},
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
        0xFF6D...0xFF6F => {},
        0xFF70 => self.wbank.write(self.legacy_mode, value),
        0xFF71 => {},
        0xFF72 => self.undoc1.write(self.legacy_mode, value),
        0xFF73 => self.undoc2.write(self.legacy_mode, value),
        0xFF74 => self.undoc3.write(self.legacy_mode, value),
        0xFF75 => self.undoc4.write(self.legacy_mode, value),
        0xFF7E => {},
        0xFF7F => {},
        0xFFFF => self.interrupt_enable.value = value,
        else => std.debug.panic("unexpected write @ 0x{X:0>4}", .{addr}),
    }
}
