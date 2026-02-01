const std = @import("std");

const GbContext = @import("gbcontext.zig");

const Panning = packed struct(u8) {
    ch1_r: bool,
    ch2_r: bool,
    ch3_r: bool,
    ch4_r: bool,
    ch1_l: bool,
    ch2_l: bool,
    ch3_l: bool,
    ch4_l: bool,
};

const Master = packed struct(u8) {
    vol_r: u3,
    r: bool,
    vol_l: u3,
    l: bool,
};

channel_1: [2]f32 = .{ 0, 0 },
channel_2: [2]f32 = .{ 0, 0 },
channel_3: [2]f32 = .{ 0, 0 },
channel_4: [2]f32 = .{ 0, 0 },

duty_1: u3 = 0,
duty_2: u3 = 0,

timer_1: i32 = 0,
timer_2: i32 = 0,
timer_3: i32 = 0,
timer_4: i32 = 0,

frame_sequencer_step: u3 = 0,

ticked: f32 = 0,

old_div: u8 = 0,

period_ch1: u11 = 0,
period_ch2: u11 = 0,

ram: [0x20]u8 = undefined,

pub const TCYCLES_PER_SAMPLE: f32 = 4194304.0 / 44100.0;

const DUTY_TABLE = [4][8]f32{
    .{ -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 1.0 },
    .{ 1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 1.0 },
    .{ 1.0, -1.0, -1.0, -1.0, -1.0, 1.0, 1.0, 1.0 },
    .{ -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1.0 },
};

pub fn tick(self: *@This(), context: *GbContext) void {
    if (context.io.speed.read_bit(7)) @panic("todo");
    const control = &context.io.nr52;

    const div = context.timer.internal_DIV.bytes.h;
    defer self.old_div = div;

    const mult: u8 = if (context.io.speed.read_bit(7)) 2 else 4;
    const edge = ((~div & self.old_div) >> (if (context.io.speed.read_bit(7)) 5 else 4)) & 1 != 0;

    if (!control.read_bit(7)) return;

    const master: Master = @bitCast(context.io.nr50.value);
    const panning: Panning = @bitCast(context.io.nr51.value);

    self.ticked += 1;

    if (edge) {
        self.frame_sequencer_step +%= 1;

        swt: switch (self.frame_sequencer_step) {
            0, 4 => {
                if (context.io.nr14.read_bit(6)) {
                    const timer = context.io.nr11.read_bits(0, 5);
                    if (timer != 0) {
                        context.io.nr11.write_bits(0, 5, timer - 1);
                        if (timer == 1) {
                            control.write_bit(0, false);
                        }
                    }
                }
            },
            2, 6 => {
                //todo sweep
                continue :swt 0;
            },
            7 => {
                //todo envelope
            },
            1, 3, 5 => {}, //nothing
        }
    }

    if (control.read_bit(0)) {
        const duty: u2 = @truncate(context.io.nr11.read_bits(6, 7));

        const channel_vol = context.io.nr12.read_bits(4, 7);

        const vol = DUTY_TABLE[duty][self.duty_1] * @as(f32, @floatFromInt(channel_vol)) / 15;

        self.timer_1 -%= mult;

        if (self.timer_1 <= 0) {
            var load: u16 = 2048;
            load -= self.period_ch1;
            self.timer_1 += load * 4;
            self.duty_1 +%= 1;
        }

        if (panning.ch1_r and master.r) {
            self.channel_1[0] += vol;
        }
        if (panning.ch1_l and master.l) {
            self.channel_1[1] += vol;
        }
    }
}

pub fn read_sample(self: *@This()) [2]f32 {
    if (self.ticked == 0) return .{ 0, 0 };
    const mean_r = self.channel_1[0]; //(self.channel_1[0] + self.channel_2[0] + self.channel_3[0] + self.channel_4[0]) / 4;
    const mean_l = self.channel_1[1]; //(self.channel_1[1] + self.channel_2[1] + self.channel_3[1] + self.channel_4[1]) / 4;
    return .{ mean_r / self.ticked, mean_l / self.ticked };
}

pub fn reset_sample(self: *@This()) void {
    self.channel_1 = .{ 0, 0 };
    self.channel_2 = .{ 0, 0 };
    self.channel_3 = .{ 0, 0 };
    self.channel_4 = .{ 0, 0 };
    self.ticked = 0;
}

pub fn reset(self: *@This()) void {
    self.timer_1 = 0;
    self.timer_2 = 0;
    self.timer_3 = 0;
    self.timer_4 = 0;
}
