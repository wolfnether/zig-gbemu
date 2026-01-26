const std = @import("std");

const rl = @import("raylib");

const PpuStructure = @import("structure/ppu.zig");
const GbContext = @import("gbcontext.zig");
const Fetcher = @import("fetcher.zig");

const Ppu = @This();

const GbColor = packed struct(u16) { r: u5, g: u5, b: u5, _: u1 };

fetcher: Fetcher = .{},

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

stat_irq_line: bool = false,

skip_frame: bool = false,

pub fn tick(self: *Ppu, context: *GbContext) void {
    if (!self.control.enable) return;
    const ppu_tick: u8 = if (context.io.speed.read_bit(7)) 2 else 4;
    for (0..ppu_tick) |_| {
        self.status.lyc_eq_ly = self.ly == self.lyc;
        const old_stat_irq = self.stat_irq_line;

        if (self.lx == 80 and self.status.ppu_mode == .OAM_SCAN) {
            self.oam_scan();
            self.status.ppu_mode = .DRAW;
            self.fetcher.pixels_to_discard = self.scx % 8;
        }

        if (self.status.ppu_mode == .DRAW) {
            if (!self.fetcher.window_activated and self.wy == self.ly) {
                self.fetcher.window_activated = true;
            }
            if (self.lx > 86) self.fetcher.step(context);
            self.draw_pixel();
            if (self.render_x == 160) {
                self.status.ppu_mode = .HBLANK;
                //std.debug.print(">{} - {} - {} <\n", .{ self.ly, self.scx, self.lx - 80 });
            }
        }

        const mode_irq = switch (self.status.ppu_mode) {
            .HBLANK => self.status.mode_0_int,
            .VBLANK => self.status.mode_1_int,
            .OAM_SCAN => self.status.mode_2_int,
            .DRAW => false,
        };
        const lyc_irq = self.status.lyc_int and self.status.lyc_eq_ly;
        self.stat_irq_line = mode_irq or lyc_irq;

        if (self.stat_irq_line and !old_stat_irq) {
            context.request_interrupt(.stat);
        }

        self.lx += 1;

        if (self.lx == 456) {
            self.lx = 0;
            self.ly += 1;
            self.render_x = 0;
            self.fetcher.reset();

            if (self.ly == 154) {
                self.fetcher.window_activated = false;
                self.ly = 0;
                self.status.ppu_mode = .OAM_SCAN;
            } else if (self.ly == 144) {
                self.status.ppu_mode = .VBLANK;
                if (self.skip_frame) {
                    self.skip_frame = false;
                } else {
                    context.request_interrupt(.vblank);
                }
                self.fetcher.window_line_counter = 0;
            } else if (self.ly < 144) {
                self.status.ppu_mode = .OAM_SCAN;
            }
        }
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
        const obj_enabled = self.control.obj_enable;
        const bg_transparent = background.raw_color == 0;
        const no_priority = !object.priority and !background.priority;
        const draw_object_pixel = obj_enabled and object.raw_color != 0 and (bg_disabled or bg_transparent or no_priority);

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
            .a = 0xFE,
        };

        self.render_x += 1;
    }
}

fn oam_scan(self: *Ppu) void {
    self.fetcher.visible_sprite_count = 0;

    const sprite_height: u8 = if (self.control.obj_size) 16 else 8;
    const current_line: i16 = @intCast(self.ly);

    // Parcourir les 40 sprites dans l'OAM
    var i: u8 = 0;
    while (i < 40) : (i += 1) {
        if (self.fetcher.visible_sprite_count >= 10) break;

        const oam_offset: usize = @as(usize, i) * 4;
        const y = self.oam[oam_offset];
        const x = self.oam[oam_offset + 1];
        const tile_id = self.oam[oam_offset + 2];
        const flags = self.oam[oam_offset + 3];

        const sprite_y: i16 = @intCast(y);
        const sprite_top = sprite_y - 16;
        const sprite_bottom = sprite_top + @as(i16, sprite_height);

        // Vérifier si le sprite est visible sur cette ligne
        if (current_line >= sprite_top and current_line < sprite_bottom) {
            self.fetcher.visible_sprites[self.fetcher.visible_sprite_count] = .{
                .y = y,
                .x = x,
                .tile_id = tile_id,
                .flags = flags,
                .idx = i,
            };
            self.fetcher.visible_sprite_count += 1;
        }
    }

    // Trier les sprites par priorité
    if (self.priority_mode) {
        std.mem.sort(PpuStructure.Object, self.fetcher.visible_sprites[0..self.fetcher.visible_sprite_count], {}, sprite_compare);
    }
}

fn sprite_compare(_: void, a: PpuStructure.Object, b: PpuStructure.Object) bool {
    return if (a.x == b.x) a.idx < b.idx else a.x < b.x;
}
