value: u8,
read_mask: u8,
write_mask: u8,
cbg_only: bool,

pub fn init(
    cbg_only: bool,
    read_mask: u8,
    write_mask: u8,
    value: u8,
) @This() {
    return .{
        .value = value,
        .read_mask = read_mask,
        .write_mask = write_mask,
        .cbg_only = cbg_only,
    };
}

pub fn read(self: *@This(), is_compatibility_mode: bool) u8 {
    return if (is_compatibility_mode and self.cbg_only) 0xFF else self.value | ~self.read_mask;
}

pub fn read_bit(self: *@This(), bit: u3) bool {
    const shifted = self.value >> bit;
    const masked = shifted & 1;
    return masked == 1;
}

pub fn write(self: *@This(), is_compatibility_mode: bool, value: u8) void {
    if (is_compatibility_mode and self.cbg_only) return;
    self.value = (self.value & ~self.write_mask) | (value & self.write_mask);
}

pub fn write_bit(self: *@This(), bit: u3, value: bool) void {
    const mask = @as(u8, 1) << bit;
    if (value) {
        self.value |= mask;
    } else {
        self.value &= ~mask;
    }
}
