const std = @import("std");

const GbContext = @import("gbcontext.zig");

// ============================================================
// APU squelette — 4 canaux + séquenceur + mixer
// tick() est appelé 1x par M-cycle (cf gbcontext.tick).
// TODO = logique à remplir, structure/compil = OK.
// ============================================================

pub const TCYCLES_PER_SAMPLE: f32 = 4194304.0 / 44100.0;

const DUTY_TABLE = [4][8]f32{
    .{ -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 1.0 },
    .{ 1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 1.0 },
    .{ 1.0, -1.0, -1.0, -1.0, -1.0, 1.0, 1.0, 1.0 },
    .{ -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1.0 },
};

// ---------- helpers ----------

/// Enveloppe volume (NR12/NR22/NR42).
pub const Envelope = struct {
    volume: u4 = 0, // volume courant 0..15
    initial: u4 = 0, // NRx2 bits 4-7
    increase: bool = false, // NRx2 bit 3
    period: u3 = 0, // NRx2 bits 0-2
    timer: u3 = 0,

    pub fn reload(self: *Envelope, nrx2: u8) void {
        self.initial = @truncate((nrx2 >> 4) & 0xF);
        self.increase = (nrx2 & 0x08) != 0;
        self.period = @truncate(nrx2 & 0x07);
        self.volume = self.initial;
        self.timer = self.period;
    }

    pub fn tick(self: *Envelope) void {
        // TODO: appelé sur step 7 du séquenceur.
        // if period==0 return.
        // timer-=1, si 0: timer=period, volume +1/-1 si dans 0..15.
        if (self.period == 0) return;
        if (self.timer == 0) self.timer = self.period;
        self.timer -%= 1;
        if (self.timer == 0) {
            self.timer = self.period;
            if (self.increase and self.volume < 15) self.volume += 1;
            if (!self.increase and self.volume > 0) self.volume -= 1;
        }
    }

    pub fn dac_on(nrx2: u8) bool {
        return (nrx2 & 0xF8) != 0;
    }

    pub fn output(self: *const Envelope, duty_val: f32) f32 {
        // duty_val = ±1, scalé par volume.
        return duty_val * @as(f32, @floatFromInt(self.volume)) / 15.0;
    }
};

/// Sweep CH1 (NR10). TODO: calcul fréquence réel.
pub const Sweep = struct {
    period: u3 = 0, // NR10 bits 4-6
    negate: bool = false, // NR10 bit 3
    shift: u3 = 0, // NR10 bits 0-2
    timer: u4 = 0, // 1..8 (period 0 = 8)
    enabled: bool = false,
    shadow_period: u11 = 0,

    pub fn reload(self: *Sweep, nr10: u8, period: u11) void {
        self.period = @truncate((nr10 >> 4) & 0x07);
        self.negate = (nr10 & 0x08) != 0;
        self.shift = @truncate(nr10 & 0x07);
        self.shadow_period = period;
        self.timer = if (self.period == 0) 8 else self.period;
        self.enabled = self.period != 0 or self.shift != 0;
        // TODO: si shift != 0: faire un calcul immédiat + overflow check -> disable CH1.
    }

    pub fn tick(self: *Sweep, channel: *SquareChannel) void {
        // TODO: appelé sur steps 2/6.
        // timer-=1, si 0: reload, calculer new_period, si <=2047 et shift!=0: maj shadow+period, + overflow check.
        _ = self;
        _ = channel;
    }
};

// ---------- canaux ----------

pub const SquareChannel = struct {
    enabled: bool = false,
    dac: bool = true,

    period: u11 = 0, // 11 bits fréquence
    freq_timer: i32 = 0, // compte en T-cycles
    duty_pos: u3 = 0, // 0..7
    duty: u2 = 0, // NRx1 bits 6-7

    length_timer: u7 = 0, // 64 - (NRx1 & 0x3F), 1..64 (0 = expiré/off)
    length_enable: bool = false,

    envelope: Envelope = .{},
    sweep: Sweep = .{}, // seul CH1 s'en sert

    pub fn tick_freq(self: *SquareChannel, t_cycles: i32) void {
        if (!self.enabled) return;
        self.freq_timer -= t_cycles;
        while (self.freq_timer <= 0) {
            // (2048 - period) * 4 T-cycles par pas de duty.
            const load: i32 = @as(i32, 2048 - @as(u16, self.period)) * 4;
            self.freq_timer += load;
            self.duty_pos +%= 1;
        }
    }

    pub fn tick_length(self: *SquareChannel, nr52_bit_clear: *bool) void {
        // TODO: appeler sur steps 0/2/4/6 si length_enable.
        if (!self.length_enable or !self.enabled) return;
        if (self.length_timer == 0) return; // déjà à 0 = plein? voir trigger
        self.length_timer -%= 1;
        if (self.length_timer == 0) {
            self.enabled = false;
            nr52_bit_clear.* = true; // demander clear NR52.x
        }
    }

    pub fn dac_output(self: *const SquareChannel) f32 {
        if (!self.enabled or !self.dac) return 0;
        const d = DUTY_TABLE[self.duty][self.duty_pos];
        return self.envelope.output(d);
    }

    pub fn trigger(self: *SquareChannel, nrx1: u8, nrx2: u8, nrx4: u8, period: u11, with_sweep_nr10: ?u8) void {
        self.dac = Envelope.dac_on(nrx2);
        self.enabled = self.dac; // si DAC off, reste OFF
        if (!self.enabled) return;
        self.period = period;
        self.duty = @truncate((nrx1 >> 6) & 0x03);
        // length: 64 - (NRx1 & 0x3F), donc 0 dans le registre = 64 ticks.
        // TODO: nuance "full length" vs trigger + extra clock obscure; simplifié ici.
        self.length_timer = 64 - @as(u7, @truncate(nrx1 & 0x3F));
        self.length_enable = (nrx4 & 0x40) != 0;
        self.envelope.reload(nrx2);
        self.freq_timer = @as(i32, 2048 - @as(u16, period)) * 4;
        self.duty_pos = 0;
        if (with_sweep_nr10) |nr10| {
            self.sweep.reload(nr10, period);
        }
        // TODO: obscure "extra length clock" si length_enable set pendant un step impair.
    }
};

pub const WaveChannel = struct {
    enabled: bool = false,
    dac: bool = true,

    period: u11 = 0,
    freq_timer: i32 = 0,
    pos: u5 = 0, // 0..31 (32 nibbles)
    length_timer: u9 = 0, // 0..255
    length_enable: bool = false,
    volume_code: u2 = 0, // NR32 bits 5-6: 0=mute,1=100%,2=50%,3=25%

    pub fn tick_freq(self: *WaveChannel, t_cycles: i32, wave_ram: *[0x20]u8) void {
        if (!self.enabled) return;
        _ = wave_ram;
        self.freq_timer -= t_cycles;
        while (self.freq_timer <= 0) {
            const load: i32 = @as(i32, 2048 - @as(u16, self.period)) * 2;
            self.freq_timer += load;
            self.pos +%= 1;
        }
    }

    pub fn tick_length(self: *WaveChannel, clear: *bool) void {
        if (!self.length_enable or !self.enabled) return;
        if (self.length_timer == 0) return;
        self.length_timer -%= 1;
        if (self.length_timer == 0) {
            self.enabled = false;
            clear.* = true;
        }
    }

    pub fn dac_output(self: *const WaveChannel, wave_ram: *const [0x20]u8) f32 {
        if (!self.enabled or !self.dac) return 0;
        if (self.volume_code == 0) return 0;
        // TODO: lire nibble: byte = ram[pos/2], high nibble si pos pair.
        const byte = wave_ram[self.pos / 2];
        const nibble: u4 = if (self.pos % 2 == 0) @truncate(byte >> 4) else @truncate(byte & 0xF);
        const sample: f32 = @as(f32, @floatFromInt(nibble)) / 15.0 * 2.0 - 1.0; // -1..1
        const div: f32 = switch (self.volume_code) {
            0 => 1, // mute déjà géré
            1 => 1.0,
            2 => 2.0,
            3 => 4.0,
        };
        return sample / div;
    }

    pub fn trigger(self: *WaveChannel, nr34: u8, period: u11, nr30_dac: bool, nr32: u8, nr31: u8) void {
        self.dac = (nr30_dac);
        self.enabled = self.dac;
        if (!self.enabled) return;
        self.period = period;
        self.volume_code = @truncate((nr32 >> 5) & 0x03);
        self.length_timer = 256 - @as(u9, nr31); // 1..256
        self.length_enable = (nr34 & 0x40) != 0;
        self.freq_timer = @as(i32, 2048 - @as(u16, period)) * 2;
        self.pos = 0;
    }
};

pub const NoiseChannel = struct {
    enabled: bool = false,
    dac: bool = true,

    freq_timer: i32 = 0,
    lfsr: u15 = 0x7FFF,
    width_7bit: bool = false,
    clock_shift: u4 = 0,
    divisor_code: u3 = 0,

    length_timer: u7 = 0, // 64 - (NR41 & 0x3F), 1..64
    length_enable: bool = false,
    envelope: Envelope = .{},

    pub fn tick_freq(self: *NoiseChannel, t_cycles: i32) void {
        if (!self.enabled) return;
        self.freq_timer -= t_cycles;
        while (self.freq_timer <= 0) {
            // TODO: load = divisor_table[divisor_code] << clock_shift (en T-cycles)
            const base: i32 = switch (self.divisor_code) {
                0 => 8,
                1 => 16,
                2 => 32,
                3 => 48,
                4 => 64,
                5 => 80,
                6 => 96,
                7 => 112,
            };
            const load = base << self.clock_shift;
            self.freq_timer += load;
            // TODO: LFSR step:
            // bit = (lfsr0 ^ lfsr1) & 1; lfsr >>= 1; lfsr14 = bit; if 7bit: lfsr6 = bit.
            const b0: u15 = self.lfsr & 1;
            const b1: u15 = (self.lfsr >> 1) & 1;
            const nb: u15 = b0 ^ b1;
            self.lfsr >>= 1;
            self.lfsr |= (nb << 14);
            if (self.width_7bit) {
                if (nb == 1) self.lfsr |= (@as(u15, 1) << 6) else self.lfsr &= ~(@as(u15, 1) << 6);
            }
        }
    }

    pub fn tick_length(self: *NoiseChannel, clear: *bool) void {
        if (!self.length_enable or !self.enabled) return;
        if (self.length_timer == 0) return;
        self.length_timer -%= 1;
        if (self.length_timer == 0) {
            self.enabled = false;
            clear.* = true;
        }
    }

    pub fn dac_output(self: *const NoiseChannel) f32 {
        if (!self.enabled or !self.dac) return 0;
        const bit: f32 = if ((self.lfsr & 1) == 0) 1.0 else -1.0;
        return self.envelope.output(bit);
    }

    pub fn trigger(self: *NoiseChannel, nr41: u8, nr42: u8, nr43: u8, nr44: u8) void {
        self.dac = Envelope.dac_on(nr42);
        self.enabled = self.dac;
        if (!self.enabled) return;
        self.length_timer = 64 - @as(u7, @truncate(nr41 & 0x3F));
        self.length_enable = (nr44 & 0x40) != 0;
        self.envelope.reload(nr42);
        self.clock_shift = @truncate((nr43 >> 4) & 0xF);
        self.width_7bit = (nr43 & 0x08) != 0;
        self.divisor_code = @truncate(nr43 & 0x07);
        self.lfsr = 0x7FFF;
        self.freq_timer = 8; // sera recalculé au prochain tick
    }
};

// ---------- APU top ----------

const Apu = @This();

ch1: SquareChannel = .{},
ch2: SquareChannel = .{},
ch3: WaveChannel = .{},
ch4: NoiseChannel = .{},

frame_sequencer_step: u3 = 0,
old_div: u8 = 0,

// accumulateur mixer (moyenné dans read_sample)
acc_l: f32 = 0,
acc_r: f32 = 0,
ticked: f32 = 0,

// Wave RAM (FF30-FF3F). Gardé ici pour compat io.zig.
ram: [0x20]u8 = [_]u8{0} ** 0x20,

// ----- helpers périodes (appelés depuis io.zig) -----
pub fn set_ch1_period_low(self: *Apu, v: u8) void {
    self.ch1.period = (self.ch1.period & 0x700) | v;
}
pub fn set_ch1_period_high(self: *Apu, v: u3) void {
    self.ch1.period = (self.ch1.period & 0xFF) | (@as(u11, v) << 8);
}
pub fn set_ch2_period_low(self: *Apu, v: u8) void {
    self.ch2.period = (self.ch2.period & 0x700) | v;
}
pub fn set_ch2_period_high(self: *Apu, v: u3) void {
    self.ch2.period = (self.ch2.period & 0xFF) | (@as(u11, v) << 8);
}
pub fn set_ch3_period_low(self: *Apu, v: u8) void {
    self.ch3.period = (self.ch3.period & 0x700) | v;
}
pub fn set_ch3_period_high(self: *Apu, v: u3) void {
    self.ch3.period = (self.ch3.period & 0xFF) | (@as(u11, v) << 8);
}

pub fn trigger_ch1(self: *Apu, ctx: *GbContext) void {
    const period = self.ch1.period;
    self.ch1.trigger(ctx.io.nr11.value, ctx.io.nr12.value, ctx.io.nr14.value, period, ctx.io.nr10.value);
}
pub fn trigger_ch2(self: *Apu, ctx: *GbContext) void {
    const period = self.ch2.period;
    self.ch2.trigger(ctx.io.nr21.value, ctx.io.nr22.value, ctx.io.nr24.value, period, null);
}
pub fn trigger_ch3(self: *Apu, ctx: *GbContext) void {
    const period = self.ch3.period;
    const dac = ctx.io.nr30.read_bit(7);
    self.ch3.trigger(ctx.io.nr34.value, period, dac, ctx.io.nr32.value, ctx.io.nr31.value);
}
pub fn trigger_ch4(self: *Apu, ctx: *GbContext) void {
    self.ch4.trigger(ctx.io.nr41.value, ctx.io.nr42.value, ctx.io.nr43.value, ctx.io.nr44.value);
}

// ----- tick principal -----
pub fn tick(self: *Apu, context: *GbContext) void {
    const double_speed = context.io.speed.read_bit(7);
    const t_cycles: i32 = if (double_speed) 2 else 4;

    const div: u8 = context.timer.internal_DIV.bytes.h;
    defer self.old_div = div;
    // falling edge du bit 4 (normal) / 5 (double) — cf Pan Docs frame sequencer
    const bit: u3 = if (double_speed) 5 else 4;
    // NOTE: old_div/div sont le byte HIGH de DIV, donc le bit à tester est (bit-8)? On garde la formule historique:
    // edge = falling edge de DIV bit (4 ou 5 du 16-bit) => bit (4-8?) dans le byte high.
    // Simplifié: on détecte via le byte high comme avant; à vérifier au test audio.
    const shift: u3 = if (double_speed) 5 - 0 else 4 - 0; // TODO: corriger l'index exact (voir timer.internal_DIV 16-bit)
    _ = shift;
    const edge = ((~div & self.old_div) >> @as(u3, if (double_speed) 5 else 4)) & 1 != 0;
    _ = bit;

    const nr52 = &context.io.nr52;
    if (!nr52.read_bit(7)) {
        // APU off: accumulateur silencieux mais on garde ticked pour read_sample.
        self.ticked += 1;
        return;
    }

    // 1. Séquenceur 512 Hz
    if (edge) {
        self.frame_sequencer_step +%= 1;
        self.tick_frame_sequencer(context);
    }

    // 2. Timers fréquence (duty/wave/lfsr)
    // TODO: ne ticker que si CHx enabled (déjà gardé dans chaque tick_freq).
    self.ch1.tick_freq(t_cycles);
    self.ch2.tick_freq(t_cycles);
    self.ch3.tick_freq(t_cycles, &self.ram);
    self.ch4.tick_freq(t_cycles);

    // 3. Mixer -> accumulateur
    // NR50: bits 7/3 = entrée Vin (cartouche, non émulée) -> ignorés.
    // Bits 6-4 / 2-0 = volumes SO2/SO1, toujours appliqués.
    const master_l_vol: f32 = @as(f32, @floatFromInt((context.io.nr50.value >> 4) & 0x07)) + 1.0;
    const master_r_vol: f32 = @as(f32, @floatFromInt(context.io.nr50.value & 0x07)) + 1.0;
    const panning = context.io.nr51.value;

    const s1 = self.ch1.dac_output();
    const s2 = self.ch2.dac_output();
    const s3 = self.ch3.dac_output(&self.ram);
    const s4 = self.ch4.dac_output();

    // TODO: diviser par 4 (moyenne des 4 DAC) comme sur HW ? À calibrer.
    var out_l: f32 = 0;
    var out_r: f32 = 0;
    if ((panning & 0x10) != 0) out_l += s1;
    if ((panning & 0x20) != 0) out_l += s2;
    if ((panning & 0x40) != 0) out_l += s3;
    if ((panning & 0x80) != 0) out_l += s4;
    if ((panning & 0x01) != 0) out_r += s1;
    if ((panning & 0x02) != 0) out_r += s2;
    if ((panning & 0x04) != 0) out_r += s3;
    if ((panning & 0x08) != 0) out_r += s4;

    out_l /= 4.0;
    out_r /= 4.0;
    out_l *= master_l_vol / 8.0;
    out_r *= master_r_vol / 8.0;

    // Clamp soft
    out_l = std.math.clamp(out_l, -1.0, 1.0);
    out_r = std.math.clamp(out_r, -1.0, 1.0);

    self.acc_l += out_l;
    self.acc_r += out_r;
    self.ticked += 1;
}

fn tick_frame_sequencer(self: *Apu, context: *GbContext) void {
    // Steps: 0=len,1=-,2=len+sweep,3=-,4=len,5=-,6=len+sweep,7=envelope
    switch (self.frame_sequencer_step) {
        0, 4 => {
            var c1 = false;
            var c2 = false;
            var c3 = false;
            var c4 = false;
            self.ch1.tick_length(&c1);
            self.ch2.tick_length(&c2);
            self.ch3.tick_length(&c3);
            self.ch4.tick_length(&c4);
            if (c1) context.io.nr52.write_bit(0, false);
            if (c2) context.io.nr52.write_bit(1, false);
            if (c3) context.io.nr52.write_bit(2, false);
            if (c4) context.io.nr52.write_bit(3, false);
        },
        2, 6 => {
            // length + sweep
            var c1 = false;
            var c2 = false;
            var c3 = false;
            var c4 = false;
            self.ch1.tick_length(&c1);
            self.ch2.tick_length(&c2);
            self.ch3.tick_length(&c3);
            self.ch4.tick_length(&c4);
            if (c1) context.io.nr52.write_bit(0, false);
            if (c2) context.io.nr52.write_bit(1, false);
            if (c3) context.io.nr52.write_bit(2, false);
            if (c4) context.io.nr52.write_bit(3, false);
            self.ch1.sweep.tick(&self.ch1);
            // TODO: si sweep overflow -> nr52 bit0 = false + ch1.enabled=false
            if (!self.ch1.enabled) context.io.nr52.write_bit(0, false);
            self.ch1.period = self.ch1.sweep.shadow_period; // TODO: seulement si sweep a maj
        },
        7 => {
            self.ch1.envelope.tick();
            self.ch2.envelope.tick();
            self.ch4.envelope.tick();
            // CH3 n'a pas d'enveloppe
        },
        1, 3, 5 => {},
    }
}

// ----- sortie audio (appelé depuis main.zig) -----
pub fn read_sample(self: *Apu) [2]f32 {
    if (self.ticked == 0) return .{ 0, 0 };
    // main.zig attend [L, R]? ton ancien code poussait (samples[0], samples[1]) = (R?, L?) — vérifier l'ordre !
    // Ici on retourne {left, right} moyennés.
    return .{ self.acc_l / self.ticked, self.acc_r / self.ticked };
}

pub fn reset_sample(self: *Apu) void {
    self.acc_l = 0;
    self.acc_r = 0;
    self.ticked = 0;
}

/// Appelé quand NR52.7 passe à 0 (power off). Remet tout à zéro.
pub fn reset(self: *Apu) void {
    self.ch1 = .{};
    self.ch2 = .{};
    self.ch3 = .{};
    self.ch4 = .{};
    self.frame_sequencer_step = 0;
    self.acc_l = 0;
    self.acc_r = 0;
    self.ticked = 0;
    // NOTE: on ne touche pas à self.ram (wave RAM conservée sur HW).
}
