const std = @import("std");

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

/// RTC à deux registres :
/// - rtc_base[5] = valeur cartouche (s, m, h, dl, dh) au moment de rtc_host_base_ns.
///   dh: bit0 = jour bit8, bit6 = halt, bit7 = carry.
/// - rtc_host_base_ns = heure hôte (.real, ns) correspondante, null = jamais posée.
/// Lecture = base + (now - host_base), sauf halt (figé). Le temps passe donc
/// émulateur éteint (comportement battery).
/// Latch (0x00 puis 0x01 sur 0x6000-0x7FFF) fige le calcul dans rtc_latched,
/// que retournent les lectures 0xA000-0xBFFF (banques 0x08-0x0C).
rtc_base: [5]u8 = .{0} ** 5,
rtc_host_base_ns: ?i128 = null,
rtc_latched: [5]u8 = .{0} ** 5,
latching_rtc: bool = false,

mode: bool = false,

ram_enabled: bool = false,

rom_bank: u8 = 0,
ram_bank: u8 = 0,

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
                if (mapper.ram.len == 0) return 0xFF;
                const address = RamAddress{
                    ._0 = @truncate(addr),
                    ._1 = self.ram_bank,
                };
                const comp_addr: u32 = @bitCast(address);
                const mod_addr = comp_addr % mapper.ram.len;
                return mapper.ram[mod_addr];
            } else if (0x08 <= self.ram_bank and self.ram_bank <= 0x0C) {
                return self.rtc_latched[self.ram_bank - 0x08];
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
                self.rtc_latched = self.current_regs(mapper);
            } else {
                self.latching_rtc = false;
            }
        },
        0xA000...0xBFFF => {
            if (!self.ram_enabled) return;

            if (0x00 <= self.ram_bank and self.ram_bank <= 0x07) {
                if (mapper.ram.len == 0) return;
                const address = RamAddress{
                    ._0 = @truncate(addr),
                    ._1 = self.ram_bank,
                };
                const comp_addr: u32 = @bitCast(address);
                const mod_addr = comp_addr % mapper.ram.len;
                mapper.ram[mod_addr] = value;
                mapper.dirty = true;
            } else if (0x08 <= self.ram_bank and self.ram_bank <= 0x0C) {
                self.write_rtc_reg(mapper, self.ram_bank - 0x08, value);
            }
            // Banques 0x0D-0x0F inutilisées : ignorées.
        },
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    }
}

/// Registres RTC courants [s, m, h, dl, dh] = base + écoulé (sauf halt).
/// Équivaut à : base.fromNanoseconds + host_base.untilNow, en arithmétique ns.
pub fn current_regs(self: *const @This(), mapper: *const Mapper) [5]u8 {
    const dh = self.rtc_base[4];
    const base_days: i128 = @as(i128, self.rtc_base[3]) | (@as(i128, dh & 0x01) << 8);
    var total_s: i128 = ((base_days * 24 + self.rtc_base[2]) * 60 + self.rtc_base[1]) * 60 + self.rtc_base[0];

    if (dh & 0x40 == 0) { // run : ajoute l'écoulé depuis host_base
        if (self.rtc_host_base_ns) |hb| {
            var elapsed_s = @divTrunc(mapper.host_now_ns() - hb, 1_000_000_000);
            if (elapsed_s < 0) elapsed_s = 0; // horloge hôte reculée (NTP)
            total_s += elapsed_s;
        }
    }

    const days = @divTrunc(total_s, 86400);
    const carry = (dh & 0x80) != 0 or days > 511;
    const day_disp: u16 = @truncate(@as(u64, @intCast(@mod(days, 512))));
    return .{
        @truncate(@as(u64, @intCast(@mod(total_s, 60)))),
        @truncate(@as(u64, @intCast(@mod(@divTrunc(total_s, 60), 60)))),
        @truncate(@as(u64, @intCast(@mod(@divTrunc(total_s, 3600), 24)))),
        @truncate(day_disp),
        @as(u8, @truncate(day_disp >> 8)) | (dh & 0x40) | @as(u8, if (carry) 0x80 else 0),
    };
}

/// Écriture d'un registre RTC : snap du courant puis application (le temps
/// repart de host_base = now). Masques HW : s/m 6 bits, h 5 bits, dh 0xC1.
fn write_rtc_reg(self: *@This(), mapper: *Mapper, idx: u8, value: u8) void {
    var cur = self.current_regs(mapper);
    switch (idx) {
        0 => cur[0] = value & 0x3F,
        1 => cur[1] = value & 0x3F,
        2 => cur[2] = value & 0x1F,
        3 => cur[3] = value,
        4 => cur[4] = value & 0xC1,
        else => return,
    }
    self.rtc_base = cur;
    self.rtc_host_base_ns = mapper.host_now_ns();
    mapper.rtc_dirty = true;
}

pub const RTC_FILE_MAGIC = "GBRTC\x01";
pub const RTC_FILE_LEN = 6 + 16 + 5 + 1;

/// Sérialise l'état RTC pour le fichier .rtc :
/// magic(6) + host_base_ns i128 LE (16) + regs base(5) + has_base(1).
pub fn rtc_serialize(self: *const @This()) [RTC_FILE_LEN]u8 {
    var out: [RTC_FILE_LEN]u8 = undefined;
    @memcpy(out[0..6], RTC_FILE_MAGIC);
    std.mem.writeInt(i128, out[6..22], self.rtc_host_base_ns orelse 0, .little);
    @memcpy(out[22..27], &self.rtc_base);
    out[27] = if (self.rtc_host_base_ns != null) 1 else 0;
    return out;
}

/// Restaure l'état RTC depuis le contenu d'un .rtc. false si invalide.
pub fn rtc_deserialize(self: *@This(), data: []const u8) bool {
    if (data.len != RTC_FILE_LEN) return false;
    if (!std.mem.eql(u8, data[0..6], RTC_FILE_MAGIC)) return false;
    self.rtc_host_base_ns = if (data[27] == 1)
        std.mem.readInt(i128, data[6..22], .little)
    else
        null;
    @memcpy(&self.rtc_base, data[22..27]);
    self.rtc_latched = self.rtc_base;
    return true;
}
