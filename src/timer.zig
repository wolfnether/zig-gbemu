const GBContext = @import("gbcontext.zig");

const Timer = @This();

internal_DIV: u16 = 0,

pub fn set_DIV(_: *Timer, _: *GBContext, _: u8) void {
    @panic("TODO set_DIV");
}

pub fn tick(self: *Timer, _: *GBContext) void {
    self.internal_DIV +%= 1;
}
