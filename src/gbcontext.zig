const std = @import("std");

const Cardrige = @import("cartrige.zig");
pub const Register = @import("structure/register.zig").Register;

const OPCODE = @import("opcode.zig").OPCODE;
const OPCODE_NAME = @import("opcode.zig").OPCODE_NAME;

const GbContext = @This();

const InterruptType = enum(u3) { vblank = 0, stat = 1, timer = 2, serial = 3, joypad = 4 };

pub const Register8 = enum { A, B, C, D, E, H, L, HL_IND, internal };
pub const Register16 = enum { AF, BC, DE, HL, SP, HL_INC, HL_DEC };

allocator: std.mem.Allocator,
boot_rom: []u8,
ticks: usize = 0,

mapper: Cardrige.Mapper = .{},

ppu: @import("ppu.zig") = .{},
io: @import("io.zig") = .{},
timer: @import("timer.zig") = .{},
hdma: @import("hdma.zig") = .{},
dma: @import("dma.zig") = .{},

wram: [8][0x1000]u8 = undefined,
hram: [0x80]u8 = undefined,

pc: Register = .init(0),
af: Register = .init(0),
bc: Register = .init(0),
de: Register = .init(0),
hl: Register = .init(0),
sp: Register = .init(0),
internal: u8 = 0,

halted: bool = false,
stopped: bool = false,
IME: bool = false,

pub fn request_interrupt(self: *@This(), interrupt_type: InterruptType) void {
    const bit: u3 = @intFromEnum(interrupt_type);
    self.io.interrupt_flag.write_bit(bit, true);
}

pub fn set_rom(self: *GbContext, rom: []u8) !void {
    self.mapper.rom = rom;
    try Cardrige.init_cartrige(self.allocator, &self.mapper);
}

pub fn init_bios(_: *GbContext) void {}

pub fn deinit(self: *GbContext) void {
    self.mapper.deinit(self.allocator);
}

pub fn step(self: *GbContext) void {
    if (self.hdma.started and !self.hdma.status.hblank) {
        std.debug.print("Halted cause by GDMA\n", .{});
        self.tick();
        return;
    }

    self.check_interrupts();

    if (self.halted) {
        std.debug.print("Halted\n", .{});
        self.tick();
        return;
    }

    const pc = self.pc.read();
    const sp = self.sp.read();
    const opcode = self.read8_at_pc_inc();

    std.debug.print("{s} {X:0>4} {s} AF:{X:0>4} BC:{X:0>4} DE:{X:0>4} HL:{X:0>4} SP:{X:0>4} {s} IF:{b:0>5} IE:{b:0>5} [{s}{s}{s}{s}] PC[0..4]:[{X}] SP[0..4]:{X}\n", .{
        if (self.io.boot_rom_mapped) "BRM" else if (self.io.legacy_mode) "DMG" else "CGB",
        pc,
        OPCODE_NAME[opcode],
        self.af.read(),
        self.bc.read(),
        self.de.read(),
        self.hl.read(),
        self.sp.read(),
        if (self.IME) "IME" else "IMD",
        self.io.interrupt_flag.value,
        self.io.interrupt_enable.value,
        if (self.af.flags.z) "Z" else "-",
        if (self.af.flags.n) "N" else "-",
        if (self.af.flags.h) "H" else "-",
        if (self.af.flags.c) "C" else "-",
        [_]u8{
            self.read_bus_internal(pc +% 0),
            self.read_bus_internal(pc +% 1),
            self.read_bus_internal(pc +% 2),
            self.read_bus_internal(pc +% 3),
        },
        [_]u8{
            self.read_bus_internal(sp +% 0),
            self.read_bus_internal(sp +% 1),
            self.read_bus_internal(sp +% 2),
            self.read_bus_internal(sp +% 3),
        },
    });

    OPCODE[opcode](self, opcode);
}

pub fn tick(self: *GbContext) void {
    self.ticks += 1;
    self.timer.tick(self);
    self.ppu.tick(self);
    self.dma.tick(self);
    if (!self.halted) self.hdma.tick(self);
}

fn check_interrupts(self: *@This()) void {
    const IE = self.io.interrupt_enable.read_bits(0, 5);
    const IF = self.io.interrupt_flag.read_bits(0, 5);
    const pending = IE & IF;

    self.halted &= IE == 0;

    if (pending == 0) return;

    if (!self.IME) return;

    self.IME = false;

    self.service_interrupt();
}

fn service_interrupt(self: *@This()) void {
    self.tick();
    self.tick();

    const IE = self.io.interrupt_enable.read_bits(0, 5);
    const IF = self.io.interrupt_flag.read_bits(0, 5);

    const pending = IE & IF;
    const bit: u3 = @truncate(@ctz(pending));

    self.push8(self.pc.bytes.h);

    if (bit != 0)
        std.debug.print("serviing interrupt {}\n", .{bit});

    if (self.io.interrupt_enable.read_bits(0, 5) & self.io.interrupt_flag.read_bits(0, 5) == 0) {
        self.pc.value = 0;
        self.tick();
    } else {
        self.io.interrupt_flag.write_bit(bit, false);
        self.push8(self.pc.bytes.l);
        self.pc.value = 0x0040 + (@as(u16, bit) * 8);
    }
    self.tick();
}

pub inline fn read8_at_pc_inc(self: *GbContext) u8 {
    defer self.pc.inc();

    return self.read_bus(self.pc.value);
}

pub inline fn read16_at_pc_inc(self: *GbContext) Register {
    return Register{
        .bytes = .{
            .l = self.read8_at_pc_inc(),
            .h = self.read8_at_pc_inc(),
        },
    };
}

pub fn read_bus(self: *GbContext, addr: u16) u8 {
    self.tick();

    return self.read_bus_internal(addr);
}

pub fn read_bus_internal(self: *GbContext, addr: u16) u8 {
    if (self.io.boot_rom_mapped) {
        if (addr < 0x0100 or (0x0200 <= addr and addr < 0x0900)) {
            return self.boot_rom[addr];
        }
    }

    const wbank = self.io.wbank.value;
    const vbank = self.io.vbank.value;

    return swt: switch (addr) {
        0x0000...0x7FFF => self.mapper.read_bus(addr),
        0x8000...0x9FFF => self.ppu.vram[vbank][addr - 0x8000],
        0xC000...0xCFFF => |a| self.wram[0][a - 0xC000],
        0xD000...0xDFFF => |a| self.wram[wbank][a - 0xD000],
        0xE000...0xFDFF => continue :swt addr - 0x2000,
        0xFE00...0xFE9F => self.ppu.oam[addr - 0xFE00],
        0xFF00...0xFF7F => self.io.read(self, addr),
        0xFF80...0xFFFE => self.hram[addr - 0xFF80],
        0xFFFF => self.io.read(self, 0xFFFF),
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    };
}

pub fn write_bus_internal(self: *GbContext, addr: u16, value: u8) void {
    if (self.io.boot_rom_mapped) {
        if (addr < 0x0100 or (addr < 0x0200 and addr <= 0x0900)) {
            return;
        }
    }

    const wbank = self.io.wbank.value;
    const vbank = self.io.vbank.value;

    switch (addr) {
        0x0000...0x7FFF => self.mapper.write_bus(addr, value),
        0x8000...0x9FFF => self.ppu.vram[vbank][addr - 0x8000] = value,
        0xC000...0xCFFF => self.wram[0][addr - 0xC000] = value,
        0xD000...0xDFFF => self.wram[wbank][addr - 0xD000] = value,
        0xFE00...0xFE9F => self.ppu.oam[addr - 0xFE00] = value,
        0xFF00...0xFF7F => self.io.write(self, addr, value),
        0xFF80...0xFFFE => self.hram[addr - 0xFF80] = value,
        0xFFFF => self.io.write(self, 0xffff, value),
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    }
}

pub fn write_bus(self: *GbContext, addr: u16, value: u8) void {
    self.tick();

    self.write_bus_internal(addr, value);
}

pub fn get_register8(self: *GbContext, reg: Register8) u8 {
    return switch (reg) {
        .A => self.af.bytes.h,
        .B => self.bc.bytes.h,
        .C => self.bc.bytes.l,
        .D => self.de.bytes.h,
        .E => self.de.bytes.l,
        .H => self.hl.bytes.h,
        .L => self.hl.bytes.l,
        .internal => self.internal,
        .HL_IND => self.read_bus(self.hl.value),
    };
}

pub fn set_register8(self: *GbContext, reg: Register8, value: u8) void {
    switch (reg) {
        .A => self.af.bytes.h = value,
        .B => self.bc.bytes.h = value,
        .C => self.bc.bytes.l = value,
        .D => self.de.bytes.h = value,
        .E => self.de.bytes.l = value,
        .H => self.hl.bytes.h = value,
        .L => self.hl.bytes.l = value,
        .internal => self.internal = value,
        .HL_IND => self.write_bus(self.hl.value, value),
    }
}

pub fn get_register16(self: *GbContext, reg: Register16) Register {
    return switch (reg) {
        .AF => self.af,
        .BC => self.bc,
        .DE => self.de,
        .SP => self.sp,
        .HL, .HL_INC, .HL_DEC => {
            defer if (reg == .HL_DEC) self.hl.dec();
            defer if (reg == .HL_INC) self.hl.inc();
            return self.hl;
        },
    };
}

pub fn set_register16(self: *GbContext, reg: Register16, value: Register) void {
    switch (reg) {
        .AF => {
            self.af = value;
            self.af.flags._ = 0;
        },
        .BC => self.bc = value,
        .DE => self.de = value,
        .HL => self.hl = value,
        .SP => self.sp = value,
        .HL_DEC, .HL_INC => unreachable,
    }
}

pub fn get_flags(self: *GbContext) Register.Flags {
    return self.af.flags;
}

const Flags = struct { z: ?bool = null, n: ?bool = null, h: ?bool = null, c: ?bool = null };
pub inline fn set_flags(self: *@This(), flags: Flags) void {
    if (flags.c) |c| self.af.flags.c = c;
    if (flags.h) |h| self.af.flags.h = h;
    if (flags.n) |n| self.af.flags.n = n;
    if (flags.z) |z| self.af.flags.z = z;
}

pub inline fn push8(self: *GbContext, value: u8) void {
    self.sp.dec();
    self.write_bus(self.sp.read(), value);
}

pub inline fn push16(self: *GbContext, value: Register) void {
    self.push8(value.bytes.h);
    self.push8(value.bytes.l);
}

pub inline fn pop8(self: *GbContext) u8 {
    defer self.sp.inc();
    return self.read_bus(self.sp.read());
}

pub inline fn pop16(self: *GbContext) Register {
    return Register{ .bytes = .{
        .l = self.pop8(),
        .h = self.pop8(),
    } };
}
