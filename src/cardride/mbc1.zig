const std = @import("std");

const Mapper = @import("mapper.zig");

const RomAddress = packed struct(u32) {
    _0: u14,
    _1: u5,
    _2: u2,
    _: u11 = 0,
};
const RamAddress = packed struct(u16) {
    _0: u13,
    _1: u2,
    _: u1 = 0,
};

mode: bool = false,

bank2: u2 = 0,

pub fn read(self: *@This(), mapper: *Mapper, addr: u16) u8 {
    switch (addr) {
        0x0000...0x3FFF => {
            const address = RomAddress{
                ._0 = @truncate(addr),
                ._1 = 0,
                ._2 = if (self.mode) @truncate(self.bank2) else 0,
            };

            const comp_addr: u32 = @bitCast(address);
            const mod_addr = comp_addr & (mapper.rom.len - 1);
            return mapper.rom[mod_addr];
        },
        else => std.debug.panic("Unhandled address: 0x{x:0>4}", .{addr}),
    }
}
