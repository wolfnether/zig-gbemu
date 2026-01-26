const GbContext = @import("gbcontext.zig");

// FF55: bits 0-6 = longueur (blocs de 16 octets - 1), bit 7 = mode (0=GDMA, 1=HBLANK).
// En lecture: bit 7 = 0 si transfert actif, 1 si terminé/inactif.
const Status = packed struct(u8) {
    len: u7,
    hblank: bool,
};

src: GbContext.Register = undefined,
dst: GbContext.Register = undefined,

status: Status = .{ .hblank = false, .len = 0b1111111 },
started: bool = false,
hblank_transfered: bool = false,

internal: u8 = 0,

pub fn set_status(self: *@This(), status: Status) void {
    // Écriture mode GDMA (bit7=0) pendant un transfert HBLANK actif = abort.
    if (!status.hblank and self.started and self.status.hblank) {
        self.started = false;
        return;
    }
    self.status = status;
    self.started = true;

    self.src.value &= 0xFFF0;
    self.dst.value = (self.dst.value & 0x1FF0) | 0x8000;
    self.internal = 0x10;
}

/// Lecture FF55: bit7=0 en cours, 1 si fini/inactif; bits0-6 = blocs restants - 1.
pub fn read_status(self: *const @This()) u8 {
    if (!self.started) return 0xFF;
    return @as(u8, @bitCast(self.status)) & 0x7F;
}

pub fn tick(self: *@This(), context: *GbContext) void {
    if (!self.started) return;
    if (self.status.hblank and context.ppu.status.ppu_mode != .HBLANK and self.hblank_transfered) {
        self.hblank_transfered = false;
    } else if (self.status.hblank and context.ppu.status.ppu_mode == .HBLANK and !self.hblank_transfered) {
        self.hblank_transfered = true;
        for (0..0x10) |_| {
            const data = context.read_bus_internal(self.src.read(), false);
            context.write_bus_internal(self.dst.read(), data, false);
            self.src.inc();
            self.dst.inc();
        }
        self.status.len -%= 1;
        if (self.status.len == 0b1111111) {
            self.started = false;
        }
    } else if (!self.status.hblank) {
        for (0..2) |_| {
            const data = context.read_bus_internal(self.src.read(), false);
            context.write_bus_internal(self.dst.read(), data, false);
            self.src.inc();
            self.dst.inc();
            self.internal -= 1;

            if (self.internal == 0) {
                self.internal = 0x10;
                self.status.len -%= 1;
                if (self.status.len == 0b1111111) {
                    self.started = false;
                }
            }
        }
    }
}
