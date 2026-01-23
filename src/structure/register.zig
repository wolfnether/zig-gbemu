pub const Flags = if (@import("builtin").cpu.arch.endian() == .little) packed struct(u16) {
    _: u4 = 0,
    c: bool,
    h: bool,
    n: bool,
    z: bool,
    a: u8,
} else packed struct(u16) {
    a: u8,
    _: u4 = 0,
    c: bool,
    h: bool,
    n: bool,
    z: bool,
};

pub const Register = extern union {
    value: u16,
    bytes: if (@import("builtin").cpu.arch.endian() == .little) packed struct(u16) {
        l: u8,
        h: u8,
    } else packed struct(u16) {
        h: u8,
        l: u8,
    },
    flags: Flags,

    pub inline fn inc(self: *@This()) void {
        self.value +%= 1;
    }
    pub inline fn dec(self: *@This()) void {
        self.value -%= 1;
    }
    /// add I to register u16
    /// only use is for clock and internal_DIV
    pub inline fn add(self: *@This(), i: comptime_int) void {
        self.value +%= i;
    }
    pub inline fn read(self: @This()) u16 {
        return self.value;
    }
    pub inline fn write(self: *@This(), value: u16) void {
        self.value = value;
    }
    pub inline fn init(value: u16) @This() {
        return .{ .value = value };
    }
};
