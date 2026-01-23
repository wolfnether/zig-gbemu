const std = @import("std");

const GbContext = @import("gbcontext.zig");

const Pixel = struct {
    color: u2,
    palette: u8,
    priority: bool,
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
    Sleep,
    Push,
};

const Queue = struct {
    head: usize = 0,
    tail: usize = 0,
    buffer: [8]struct { Pixel, Pixel } = undefined,

    fn push(self: *Queue, pixel: struct { Pixel, Pixel }) void {
        self.buffer[self.tail] = pixel;
        self.tail = (self.tail + 1) % self.buffer.len;
    }

    fn pop(self: *Queue) ?struct { Pixel, Pixel } {
        if (self.head == self.tail) return null;
        const pixel = self.buffer[self.head];
        self.head = (self.head + 1) % self.buffer.len;
        return pixel;
    }
};

const Fetcher = @This();

queue: Queue = .{},

x: u8 = 0,

state: FetcherState = .GetTileId,
internal_wait: bool = false,

tile_id: u8 = undefined,
tile_attrib: Attributes = undefined,
tile: GbContext.Register = undefined,

pub fn step(self: *Fetcher, context: *GbContext) void {
    if (!self.internal_wait) {
        switch (self.state) {
            .GetTileId => {
                self.fetch_tile_id(context);
                self.state = .GetTileLow;
            },
            .GetTileLow => {
                self.tile.bytes.l = fetch_tile(context, self.tile_id, 0);
                self.state = .GetTileHigh;
            },
            .GetTileHigh => {
                self.tile.bytes.h = fetch_tile(context, self.tile_id, 1);
                self.state = .Sleep;
            },
            .Sleep => self.state = .Push,
            .Push => {
                self.push_pixels(&self.queue, self.tile.value);
                self.state = .GetTileId;
            },
        }
    }
    self.internal_wait ^= true;
}

fn fetch_tile_id(self: *Fetcher, context: *GbContext) void {
    var base: u16 = 0;
    var tile_x: u16 = 0;
    var tile_y: u16 = 0;

    tile_x /= 8;
    tile_y /= 8;
    tile_y *= 32;

    base = 0x1800;
    tile_x = self.x +% context.ppu.scx;
    tile_y = context.ppu.ly +% context.ppu.scy;

    const addr = base + tile_y + tile_x;

    self.tile_id = context.ppu.vram[0][addr];
    self.tile_attrib = @bitCast(if (context.io.legacy_mode) 0 else context.ppu.vram[1][addr]);
}

fn fetch_tile(context: *GbContext, tile_id: u8, offset: u8) u8 {
    const addr = tile_id * 16 + offset;
    return context.ppu.vram[0][addr];
}

fn push_pixels(_: *Fetcher, _: *Queue, _: u16) void {}

pub fn pop_pixel(self: *Fetcher) ?struct { Pixel, Pixel } {
    return self.queue.pop();
}
