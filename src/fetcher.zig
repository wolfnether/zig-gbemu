const std = @import("std");
const Palette = @import("structure/ppu.zig").Palette;
const Object = @import("structure/ppu.zig").Object;

const GbContext = @import("gbcontext.zig");

const Pixel = struct {
    color: u2,
    palette: u8,
    priority: bool,
    raw_color: u2,
};

const Attributes = packed struct(u8) {
    palette: u3,
    bank: u1,
    _: u1,
    flip_x: bool,
    flip_y: bool,
    priority: bool,
};

const FetcherState = enum {
    GetTileId,
    GetTileLow,
    GetTileHigh,
    Push,
};

const PixelPair = struct { Pixel, Pixel };

const Queue = struct {
    data: [16]PixelPair = undefined,
    front: u4 = 0,
    back: u4 = 0,
    count: u5 = 0,

    pub fn enqueue(self: *Queue, value: PixelPair) void {
        std.debug.assert(self.count < self.data.len);
        self.data[self.back] = value;
        self.back +%= 1;
        self.count += 1;
    }

    pub fn dequeue(self: *Queue) ?PixelPair {
        if (self.count == 0) return null;
        const pixel = self.data[self.front];
        self.front +%= 1;
        self.count -= 1;
        return pixel;
    }

    pub fn len(self: *const Queue) usize {
        return self.count;
    }

    pub fn reset(self: *Queue) void {
        self.front = 0;
        self.back = 0;
        self.count = 0;
    }
};

const Fetcher = @This();

queue: Queue = .{},

x: u8 = 0,
pixels_to_discard: u8 = 0,

state: FetcherState = .GetTileId,
internal_wait: bool = false,

tile_id: u8 = undefined,
tile_attrib: Attributes = undefined,
tile_h: u8 = undefined,
tile_l: u8 = undefined,

visible_sprite_count: u8 = 0,
visible_sprites: [10]Object = undefined,

window_triggered: bool = false,
window_activated: bool = false,
window_line_counter: u8 = 0,

pub fn step(self: *Fetcher, context: *GbContext) void {
    // Check if window should trigger at this pixel
    if (!self.window_triggered and
        self.window_activated and
        context.ppu.control.window_enable and
        context.ppu.render_x >= context.ppu.wx -% 7)
    {
        self.window_triggered = true;
        self.state = .GetTileId;
        self.x = 0;
        self.pixels_to_discard = 0;
        self.queue.reset();
    }

    if (!self.internal_wait) {
        switch (self.state) {
            .GetTileId => {
                self.fetch_tile_id(context);
                self.state = .GetTileLow;
            },
            .GetTileLow => {
                self.tile_l = self.fetch_tile(context, 0);
                self.state = .GetTileHigh;
            },
            .GetTileHigh => {
                self.tile_h = self.fetch_tile(context, 1);
                self.state = .Push;
            },
            .Push => {
                if (self.queue.len() > 8) return;

                for (0..8) |i| {
                    const bit_index: u3 = @truncate(if (self.tile_attrib.flip_x) i else 7 - i);
                    const low = (self.tile_l >> bit_index) & 0x1;
                    const high = (self.tile_h >> bit_index) & 0x1;

                    const raw_color: u2 = @truncate((high << 1) | low);

                    const color = if (context.io.legacy_mode)
                        get_legacy_color(raw_color, context.ppu.bgp)
                    else
                        raw_color;

                    const screen_x = context.ppu.render_x + @as(u8, @intCast(i));
                    self.queue.enqueue(.{
                        .{
                            .color = color,
                            .raw_color = raw_color,
                            .palette = self.tile_attrib.palette,
                            .priority = self.tile_attrib.priority,
                        },
                        self.get_obj_pixel(context, screen_x) orelse .{
                            .color = 0,
                            .raw_color = 0,
                            .palette = 0,
                            .priority = false,
                        },
                    });
                }
                self.x +%= 8;
                self.state = .GetTileId;
            },
        }
    }
    self.internal_wait = !self.internal_wait;
}

pub fn reset(self: *Fetcher) void {
    self.state = .GetTileId;
    self.internal_wait = false;
    self.x = 0;
    self.queue.reset();
    self.pixels_to_discard = 0;
    if (self.window_triggered) {
        self.window_line_counter +%= 1;
    }
    self.window_triggered = false;
}

fn fetch_tile_id(self: *Fetcher, context: *GbContext) void {
    const is_window = self.window_triggered;

    var tile_map_base: u16 = 0;
    var tile_x: u16 = 0;
    var tile_y: u16 = 0;

    if (is_window) {
        tile_map_base = if (context.ppu.control.window_tile_map) 0x1C00 else 0x1800;
        tile_x = self.x;
        tile_y = self.window_line_counter;
    } else {
        tile_map_base = if (context.ppu.control.bg_tile_map) 0x1C00 else 0x1800;
        tile_x = self.x +% context.ppu.scx;
        tile_y = context.ppu.ly +% context.ppu.scy;
    }

    tile_x /= 8;
    tile_y /= 8;
    tile_y *= 32;

    const tile_map_addr = tile_map_base + tile_y + tile_x;

    self.tile_id = context.ppu.vram[0][tile_map_addr];

    const tile_attrib = if (context.io.legacy_mode) 0 else context.ppu.vram[1][tile_map_addr];
    self.tile_attrib = @bitCast(tile_attrib);
}

fn fetch_tile(self: *Fetcher, context: *GbContext, offset: u8) u8 {
    const is_window = self.window_triggered;

    var y: u8 = if (is_window)
        self.window_line_counter % 8
    else
        (context.ppu.ly +% context.ppu.scy) % 8;

    if (self.tile_attrib.flip_y) {
        y = 7 - y;
    }

    const tile_line_offset: u16 = @as(u16, y) * 2;

    const tile_data_addr: u16 = if (context.ppu.control.tile_selector)
        (@as(u16, self.tile_id) * 16) + tile_line_offset
    else
        @as(u16, @intCast(@as(i32, 0x1000) + (@as(i32, @as(i8, @bitCast(self.tile_id))) * 16) + tile_line_offset));

    const vram_bank_idx: u8 = if (context.io.legacy_mode) 0 else self.tile_attrib.bank;
    const vram_bank = context.ppu.vram[vram_bank_idx];

    return vram_bank[tile_data_addr + offset];
}

pub fn get_next_pixel(self: *Fetcher) ?PixelPair {
    while (self.pixels_to_discard > 0) {
        if (self.queue.dequeue() != null) {
            self.pixels_to_discard -= 1;
        } else {
            return null;
        }
    }
    return self.queue.dequeue();
}

pub fn get_obj_pixel(self: *Fetcher, context: *GbContext, screen_x: u8) ?Pixel {
    if (!context.ppu.control.obj_enable) return null;

    const x: i16 = @intCast(screen_x);

    for (0..self.visible_sprite_count) |i| {
        const sprite = self.visible_sprites[i];
        const sprite_x = @as(i16, sprite.x) - 8;

        if (x >= sprite_x and x < sprite_x + 8) {
            var col = @as(u8, @intCast(x - sprite_x));
            var row = @as(u8, @intCast(@as(i16, context.ppu.ly) - (@as(i16, sprite.y) - 16)));

            if (sprite.flip_x()) col = 7 - col;

            const height: u8 = if (context.ppu.control.obj_size) 16 else 8;

            if (sprite.flip_y()) row = height - 1 - row;

            var tile_id = sprite.tile_id;
            if (context.ppu.control.obj_size) {
                tile_id &= 0xFE;
                if (row >= 8) {
                    tile_id |= 1;
                    row -= 8;
                }
            }

            const bank_idx: u8 = if (!context.io.legacy_mode) sprite.get_bank() else 0;
            const bank = &context.ppu.vram[bank_idx];
            const addr = (@as(u16, tile_id) * 16) + (row * 2);

            const low_byte = bank[addr];
            const high_byte = bank[addr + 1];

            const bit_index: u3 = @intCast(7 - col);
            const bit_low = (low_byte >> bit_index) & 1;
            const bit_high = (high_byte >> bit_index) & 1;

            const raw_color: u2 = @truncate((bit_high << 1) | bit_low);

            if (raw_color == 0) continue;

            const color = if (context.io.legacy_mode) blk: {
                const dmg_palette = if (sprite.dmg_palette() == 0)
                    context.ppu.obp0
                else
                    context.ppu.obp1;
                break :blk get_legacy_color(raw_color, dmg_palette);
            } else raw_color;

            const palette = if (!context.io.legacy_mode) sprite.get_palette() else 0;

            return Pixel{
                .color = color,
                .raw_color = raw_color,
                .palette = palette,
                .priority = sprite.priority(),
            };
        }
    }
    return null;
}

fn get_legacy_color(color: u2, palette: Palette) u2 {
    return switch (color) {
        0 => palette.p0,
        1 => palette.p1,
        2 => palette.p2,
        3 => palette.p3,
    };
}
