pub const Control = packed struct(u8) {
    bg_enable: bool,
    obj_enable: bool,
    obj_size: bool,
    bg_tile_map: bool,
    tile_selector: bool,
    window_enable: bool,
    window_tile_map: bool,
    enable: bool,
};

const Mode = enum(u2) {
    HBLANK,
    VBLANK,
    OAM_SCAN,
    DRAW,
};

pub const Status = packed struct(u8) {
    ppu_mode: Mode,
    lyc_eq_ly: bool,
    mode_0_int: bool,
    mode_1_int: bool,
    mode_2_int: bool,
    lyc_int: bool,
    _: bool, //always 1
};

pub const Palette = packed struct(u8) {
    p0: u2,
    p1: u2,
    p2: u2,
    p3: u2,
};

pub const Object = packed struct {
    y: u8,
    x: u8,
    tile_id: u8,
    flags: u8,
    idx: u8,

    pub fn get_palette(self: @This()) u3 {
        return @truncate(self.flags & 0x07);
    }

    pub fn get_bank(self: @This()) u1 {
        return @truncate((self.flags >> 3) & 0x01);
    }

    pub fn flip_x(self: @This()) bool {
        return (self.flags & 0x20) != 0;
    }

    pub fn flip_y(self: @This()) bool {
        return (self.flags & 0x40) != 0;
    }

    pub fn priority(self: @This()) bool {
        return (self.flags & 0x80) != 0;
    }

    pub fn dmg_palette(self: @This()) u1 {
        return @truncate((self.flags >> 4) & 0x01);
    }
};
