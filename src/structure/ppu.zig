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

pub const Status = packed struct(u8) {
    ppu_mode: u2,
    lyc_eq_ly: bool,
    mode_0_int: bool,
    mode_1_int: bool,
    mode_2_int: bool,
    lyc_int: bool,
    _: bool, //always 1
};
