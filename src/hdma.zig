const GbContext = @import("gbcontext.zig");

const Status = packed struct(u8) {
    hblank: bool,
    len: u7,
};

src: GbContext.Register = undefined,
dst: GbContext.Register = undefined,

status: Status = .{ .hblank = false, .len = 0b1111111 },
started: bool = false,
hblank_transfered: bool = false,

internal: u8 = 0,

pub fn set_statue(self: *@This(), status: Status) void {
    self.status = status;
    self.started = true;

    self.src.value &= 0xFFF0;
    self.src.value = (self.src.value & 0x1FF0) | 0x8000;
    self.internal = 0x10;
}

pub fn tick(self: *@This(), context: *GbContext) void {
    if (!self.started) return;
    if (self.status.hblank and context.ppu.status.ppu_mode != .HBLANK and self.hblank_transfered) {
        self.hblank_transfered = false;
    } else if (self.status.hblank and context.ppu.status.ppu_mode == .HBLANK and !self.hblank_transfered) {
        @panic("Implement HDMA transfer logic");
    } else if (!self.status.hblank) {
        for (0..2) |_| {
            const data = context.read_bus_internal(self.src.read());
            context.write_bus_internal(self.dst.read(), data);
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
