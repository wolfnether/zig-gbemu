const GBContext = @import("gbcontext.zig");

const Timer = @This();

const TAC = packed struct(u3) { speed: u2, enable: bool };

internal_DIV: GBContext.Register = .init(0),
TIMA: u8 = 0,
TMA: u8 = 0,

control: TAC = .{ .enable = false, .speed = 0 },

pub fn set_DIV(_: *Timer, _: *GBContext, _: u8) void {
    @panic("TODO set_DIV");
}

pub fn set_TAC(self: *Timer, context: *GBContext, value: u3) void {
    const old_signal = self.signal();
    self.control = @bitCast(value);
    const new_signal = self.signal();
    if (old_signal and !new_signal) self.increase_tima(context);
}

fn increase_tima(self: *Timer, context: *GBContext) void {
    if (self.TIMA == 0xFF) {
        self.TIMA = self.TMA;
        context.request_interrupt(.timer);
    } else {
        self.TIMA += 1;
    }
}

inline fn signal(self: *Timer) bool {
    if (self.control.enable) return false;

    const bit: u4 = switch (self.control.speed) {
        0b00 => 9,
        0b01 => 3,
        0b10 => 5,
        0b11 => 7,
    };

    return (self.internal_DIV.read() & (@as(u16, 1) << bit)) != 0;
}

pub fn tick(self: *Timer, _: *GBContext) void {
    self.internal_DIV.inc();
}
