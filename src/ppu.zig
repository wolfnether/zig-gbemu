const std = @import("std");

const rl = @import("raylib");

const PpuStructure = @import("structure/ppu.zig");
const GbContext = @import("gbcontext.zig");

const Ppu = @This();

const GbColor = packed struct(u16) { r: u5, g: u5, b: u5, _: u1 };

fetcher: @import("fetcher.zig") = .{},

framebuffer: [160 * 144]rl.Color = undefined,
vram: [2][0x2000]u8 = undefined,
oam: [0x100]u8 = undefined,
object_palette: [0x20]GbColor = undefined,
background_palette: [0x20]GbColor = undefined,

lx: u16 = 0,
ly: u8 = 0,

scx: u8 = 0,
scy: u8 = 0,

bgp: packed struct(u8) {
    bgp0: u2,
    bgp1: u2,
    bgp2: u2,
    bgp3: u2,
} = undefined,

control: PpuStructure.Control = @bitCast(@as(u8, 0)),
status: PpuStructure.Status = @bitCast(@as(u8, 0)),

pub fn tick(self: *Ppu, context: *GbContext) void {
    if (!self.control.enable) return;
    const ppu_tick: u8 = if (context.io.speed.read_bit(7)) 2 else 4;
    for (0..ppu_tick) |_| {
        if (self.lx == 80 and self.status.ppu_mode == .OAM_SCAN) {
            self.status.ppu_mode = .DRAW;
        } else if (self.lx == 456) {
            self.lx = 0;
            self.ly += 1;

            if (self.ly == 154) {
                self.ly = 0;
                self.status.ppu_mode = .OAM_SCAN;
            }
            if (self.ly == 144) {
                self.status.ppu_mode = .VBLANK;
                context.request_interrupt(.vblank);
            } else if (self.ly < 144) {
                self.status.ppu_mode = .OAM_SCAN;
            }
        }

        if (self.status.ppu_mode == .DRAW) {
            self.tick_fetcher(context);
            self.draw_pixel();
            if (self.fetcher.x == 160) {
                self.status.ppu_mode = .HBLANK;
            }
        }

        self.lx += 1;
    }
}

pub fn write_object_palette(self: *Ppu, index: u8, value: u8) void {
    const palette: []u8 = @ptrCast(&self.object_palette);
    palette[index] = value;
}

pub fn write_background_palette(self: *Ppu, index: u8, value: u8) void {
    const palette: []u8 = @ptrCast(&self.background_palette);
    palette[index] = value;
}

fn tick_fetcher(self: *Ppu, context: *GbContext) void {
    self.fetcher.step(context);
}

fn draw_pixel(self: *Ppu) void {
    if (self.fetcher.pop_pixel()) |pixels| {
        _ = pixels[0];
        _ = pixels[1];
    }
}
