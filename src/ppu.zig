const std = @import("std");

const rl = @import("raylib");

const PpuStructure = @import("structure/ppu.zig");

framebuffer: [160 * 144]rl.Color = undefined,
vram: [2][0x2000]u8 = undefined,

controle: PpuStructure.Control = @bitCast(@as(u8, 0)),
status: PpuStructure.Status = @bitCast(@as(u8, 0)),
