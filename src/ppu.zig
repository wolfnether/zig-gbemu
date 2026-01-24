const std = @import("std");

const rl = @import("raylib");

const PpuStructure = @import("structure/ppu.zig");
const GbContext = @import("gbcontext.zig");

const Ppu = @This();

const GbColor = packed struct(u16) { r: u5, g: u5, b: u5, _: u1 };

fetcher: @import("fetcher.zig") = .{},

framebuffer: [160 * 144]rl.Color = [_]rl.Color{.gold} ** (160 * 144),
vram: [2][0x2000]u8 = undefined,
oam: [0x100]u8 = undefined,
object_palette: [0x20]GbColor = undefined,
background_palette: [0x20]GbColor = undefined,

lx: u16 = 0,
ly: u8 = 0,

lyc: u8 = 0,

scx: u8 = 0,
scy: u8 = 0,

wx: u8 = 0,
wy: u8 = 0,

bgp: PpuStructure.Palette = undefined,
obp0: PpuStructure.Palette = undefined,
obp1: PpuStructure.Palette = undefined,

render_x: u8 = 0,

control: PpuStructure.Control = @bitCast(@as(u8, 0)),
status: PpuStructure.Status = @bitCast(@as(u8, 0)),

priority_mode: bool = false,

pub fn tick(self: *Ppu, context: *GbContext) void {
    if (!self.control.enable) return;
    const ppu_tick: u8 = if (context.io.speed.read_bit(7)) 2 else 4;
    for (0..ppu_tick) |_| {
        const old_mode = self.status.ppu_mode;
        if (self.lx == 80 and self.status.ppu_mode == .OAM_SCAN) {
            self.status.ppu_mode = .DRAW;
        } else if (self.lx == 456) {
            self.lx = 0;
            self.ly += 1;
            self.render_x = 0;
            self.fetcher.reset();

            if (self.ly == 154) {
                self.ly = 0;
                self.status.ppu_mode = .OAM_SCAN;
            } else if (self.ly == 144) {
                self.status.ppu_mode = .VBLANK;
                context.request_interrupt(.vblank);
            } else if (self.ly < 144) {
                self.status.ppu_mode = .OAM_SCAN;
            }
        }

        if (self.status.ppu_mode == .DRAW) {
            self.fetcher.step(context);
            self.draw_pixel();
            if (self.render_x == 160) {
                self.status.ppu_mode = .HBLANK;
            }
        }

        const old_ly_eq = self.status.lyc_eq_ly;
        self.status.lyc_eq_ly = self.ly == self.lyc;

        if (self.status.lyc_int and !old_ly_eq and self.status.lyc_eq_ly)
            context.request_interrupt(.stat);

        if (self.status.ppu_mode != old_mode) {
            switch (self.status.ppu_mode) {
                .HBLANK => if (self.status.mode_0_int) context.request_interrupt(.stat),
                .VBLANK => if (self.status.mode_1_int) context.request_interrupt(.stat),
                .OAM_SCAN => if (self.status.mode_2_int) context.request_interrupt(.stat),
                .DRAW => {},
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

fn draw_pixel(self: *Ppu) void {
    if (self.fetcher.get_next_pixel()) |pixels| {
        var screen_offset: usize = self.ly;
        screen_offset *= 160;
        screen_offset += self.render_x;

        const background = pixels[0];
        const object = pixels[1];

        const bg_disabled = !self.control.bg_enable;
        const no_priority = !object.priority and !background.priority;
        const bg_transparent = background.color == 0;
        const draw_object_pixel = self.control.obj_enable and object.color != 0 and (bg_disabled or no_priority or bg_transparent);

        const pixel = if (draw_object_pixel) object else background;

        const palette = if (draw_object_pixel)
            self.object_palette
        else
            self.background_palette;

        const color_addr = (@as(u16, pixel.palette) * 4) + @as(u16, pixel.color);
        const color5 = palette[color_addr];

        const r: u8 = color5.r;
        const g: u8 = color5.g;
        const b: u8 = color5.b;

        self.framebuffer[screen_offset] = .{
            .r = (r << 3) | (r >> 2),
            .g = (g << 3) | (g >> 2),
            .b = (b << 3) | (b >> 2),
            .a = 0xaa,
        };

        self.render_x += 1;
    }
}
