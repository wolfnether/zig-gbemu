const GbContext = @import("gbcontext.zig");
new_source_page: u8 = 0,
source_page: u8 = 0,

active: bool = false,
bytes_transferred: u8 = 0,
wait: bool = false,
latch: bool = false,

pub fn start(self: *@This(), source_page: u8) void {
    self.new_source_page = source_page;
    self.wait = true;
    //self.bytes_transferred = 0;
    //self.source_page = self.new_source_page;
}

pub fn tick(self: *@This(), context: *GbContext) void {
    if (self.latch) {
        self.latch = false;
        self.bytes_transferred = 0;
        self.source_page = self.new_source_page;
        self.active = true;
    }
    if (self.wait) {
        self.wait = false;
        self.latch = true;
    }
    if (self.bytes_transferred == 160) {
        self.active = false;
        self.bytes_transferred = 0;
    }
    if (!self.active) return;

    const corrected_addr = if (self.source_page >= 0xFE) self.source_page - 0x20 else self.source_page;
    const source_addr: GbContext.Register = .from_bytes(corrected_addr, self.bytes_transferred);
    const dest_addr: GbContext.Register = .from_bytes(0xFE, self.bytes_transferred);

    const data = context.read_bus_internal(source_addr.read());
    context.write_bus_internal(dest_addr.read(), data, true);

    self.bytes_transferred += 1;
}
