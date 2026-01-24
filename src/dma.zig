const GbContext = @import("gbcontext.zig");
source_page: u8 = 0,

active: bool = false,
bytes_transferred: u8 = 0,

pub fn start(self: *@This(), source_page: u8) void {
    self.source_page = source_page;
    self.active = true;
    self.bytes_transferred = 0;
}
pub fn tick(self: *@This(), context: *GbContext) void {
    if (!self.active) return;

    // Calculate source and destination addresses
    const source_addr: GbContext.Register = .from_bytes(self.source_page, self.bytes_transferred);
    const dest_addr: GbContext.Register = .from_bytes(0xFE, self.bytes_transferred);

    const data = context.read_bus_internal(source_addr.read());
    context.write_bus_internal(dest_addr.read(), data);

    self.bytes_transferred += 1;

    if (self.bytes_transferred >= 0xA0) {
        self.active = false;
        self.bytes_transferred = 0;
    }
}
