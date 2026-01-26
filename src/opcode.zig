const std = @import("std");

const GBContext = @import("gbcontext.zig");

pub const OPCODE_NAME: [0x100]*const [10:0]u8 = .{
    "NOP       ",
    "LD BC,nn  ",
    "LD (BC),A ",
    "INC BC    ",
    "INC B     ",
    "DEC B     ",
    "LD B,n    ",
    "RLCA      ",
    "LD (nn),SP",
    "ADD HL,BC ",
    "LD A,(BC) ",
    "DEC BC    ",
    "INC C     ",
    "DEC C     ",
    "LD C,n    ",
    "RRCA      ",
    "STOP      ",
    "LD DE,nn  ",
    "LD (DE),A ",
    "INC DE    ",
    "INC D     ",
    "DEC D     ",
    "LD D,n    ",
    "RLA       ",
    "JR e      ",
    "ADD HL,DE ",
    "LD A,(DE) ",
    "DEC DE    ",
    "INC E     ",
    "DEC E     ",
    "LD E,n    ",
    "RRA       ",
    "JR NZ,e   ",
    "LD HL,nn  ",
    "LD (HL+),A",
    "INC HL    ",
    "INC H     ",
    "DEC H     ",
    "LD H,n    ",
    "DAA       ",
    "JR Z,e    ",
    "ADD HL,HL ",
    "LD A,(HL+)",
    "DEC HL    ",
    "INC L     ",
    "DEC L     ",
    "LD L,n    ",
    "CPL       ",
    "JR NC,e   ",
    "LD SP,nn  ",
    "LD (HL-),A",
    "INC SP    ",
    "INC (HL)  ",
    "DEC (HL)  ",
    "LD (HL),n ",
    "SCF       ",
    "JR C,e    ",
    "ADD HL,SP ",
    "LD A,(HL-)",
    "DEC SP    ",
    "INC A     ",
    "DEC A     ",
    "LD A,n    ",
    "CCF       ",
    "LD B,B    ",
    "LD B,C    ",
    "LD B,D    ",
    "LD B,E    ",
    "LD B,H    ",
    "LD B,L    ",
    "LD B,(HL) ",
    "LD B,A    ",
    "LD C,B    ",
    "LD C,C    ",
    "LD C,D    ",
    "LD C,E    ",
    "LD C,H    ",
    "LD C,L    ",
    "LD C,(HL) ",
    "LD C,A    ",
    "LD D,B    ",
    "LD D,C    ",
    "LD D,D    ",
    "LD D,E    ",
    "LD D,H    ",
    "LD D,L    ",
    "LD D,(HL) ",
    "LD D,A    ",
    "LD E,B    ",
    "LD E,C    ",
    "LD E,D    ",
    "LD E,E    ",
    "LD E,H    ",
    "LD E,L    ",
    "LD E,(HL) ",
    "LD E,A    ",
    "LD H,B    ",
    "LD H,C    ",
    "LD H,D    ",
    "LD H,E    ",
    "LD H,H    ",
    "LD H,L    ",
    "LD H,(HL) ",
    "LD H,A    ",
    "LD L,B    ",
    "LD L,C    ",
    "LD L,D    ",
    "LD L,E    ",
    "LD L,H    ",
    "LD L,L    ",
    "LD L,(HL) ",
    "LD L,A    ",
    "LD (HL),B ",
    "LD (HL),C ",
    "LD (HL),D ",
    "LD (HL),E ",
    "LD (HL),H ",
    "LD (HL),L ",
    "HALT      ",
    "LD (HL),A ",
    "LD A,B    ",
    "LD A,C    ",
    "LD A,D    ",
    "LD A,E    ",
    "LD A,H    ",
    "LD A,L    ",
    "LD A,(HL) ",
    "LD A,A    ",
    "ADD B     ",
    "ADD C     ",
    "ADD D     ",
    "ADD E     ",
    "ADD H     ",
    "ADD L     ",
    "ADD (HL)  ",
    "ADD A     ",
    "ADC B     ",
    "ADC C     ",
    "ADC D     ",
    "ADC E     ",
    "ADC H     ",
    "ADC L     ",
    "ADC (HL)  ",
    "ADC A     ",
    "SUB B     ",
    "SUB C     ",
    "SUB D     ",
    "SUB E     ",
    "SUB H     ",
    "SUB L     ",
    "SUB (HL)  ",
    "SUB A     ",
    "SBC B     ",
    "SBC C     ",
    "SBC D     ",
    "SBC E     ",
    "SBC H     ",
    "SBC L     ",
    "SBC (HL)  ",
    "SBC A     ",
    "AND B     ",
    "AND C     ",
    "AND D     ",
    "AND E     ",
    "AND H     ",
    "AND L     ",
    "AND (HL)  ",
    "AND A     ",
    "XOR B     ",
    "XOR C     ",
    "XOR D     ",
    "XOR E     ",
    "XOR H     ",
    "XOR L     ",
    "XOR (HL)  ",
    "XOR A     ",
    "OR B      ",
    "OR C      ",
    "OR D      ",
    "OR E      ",
    "OR H      ",
    "OR L      ",
    "OR (HL)   ",
    "OR A      ",
    "CP B      ",
    "CP C      ",
    "CP D      ",
    "CP E      ",
    "CP H      ",
    "CP L      ",
    "CP (HL)   ",
    "CP A      ",
    "RET NZ    ",
    "POP BC    ",
    "JP NZ,nn  ",
    "JP nn     ",
    "CALL NZ,nn",
    "PUSH BC   ",
    "ADD n     ",
    "RST 0x00  ",
    "RET Z     ",
    "RET       ",
    "JP Z,nn   ",
    "CB op     ",
    "CALL Z,nn ",
    "CALL nn   ",
    "ADC n     ",
    "RST 0x08  ",
    "RET NC    ",
    "POP DE    ",
    "JP NC,nn  ",
    "**UNKOWN**",
    "CALL NC,nn",
    "PUSH DE   ",
    "SUB n     ",
    "RST 0x10  ",
    "RET C     ",
    "RETI      ",
    "JP C,nn   ",
    "**UNKOWN**",
    "CALL C,nn ",
    "**UNKOWN**",
    "SBC n     ",
    "RST 0x18  ",
    "LDH (n),A ",
    "POP HL    ",
    "LDH (C),A ",
    "**UNKOWN**",
    "**UNKOWN**",
    "PUSH HL   ",
    "AND n     ",
    "RST 0x20  ",
    "ADD SP,e  ",
    "JP HL     ",
    "LD (nn),A ",
    "**UNKOWN**",
    "**UNKOWN**",
    "**UNKOWN**",
    "XOR n     ",
    "RST 0x28  ",
    "LDH A,(n) ",
    "POP AF    ",
    "LDH A,(C) ",
    "DI        ",
    "**UNKOWN**",
    "PUSH AF   ",
    "OR n      ",
    "RST 0x30  ",
    "LD HL,SP+e",
    "LD SP,HL  ",
    "LD A,(nn) ",
    "EI        ",
    "**UNKOWN**",
    "**UNKOWN**",
    "CP n      ",
    "RST 0x38  ",
};

pub const OPCODE: [0x100]*const fn (self: *GBContext, opcode: u8) void = blk: {
    const OpcodeMask = struct {
        mask: u8,
        instruction: u8,
        function: *const fn (self: *GBContext, opcode: u8) void,
    };

    const opcode_masks = [_]OpcodeMask{
        .{ .mask = 0xFF, .instruction = 0x00, .function = &nop },
        .{ .mask = 0xFF, .instruction = 0x07, .function = &rlca },
        .{ .mask = 0xFF, .instruction = 0x08, .function = &ld_sp_dir },
        .{ .mask = 0xFF, .instruction = 0x0F, .function = &rrca },
        .{ .mask = 0xFF, .instruction = 0x10, .function = &stop },
        .{ .mask = 0xFF, .instruction = 0x17, .function = &rla },
        .{ .mask = 0xFF, .instruction = 0x18, .function = &jr },
        .{ .mask = 0xFF, .instruction = 0x1F, .function = &rra },
        .{ .mask = 0xFF, .instruction = 0x27, .function = &daa },
        .{ .mask = 0xFF, .instruction = 0x2F, .function = &cpl },
        .{ .mask = 0xFF, .instruction = 0x37, .function = &scf },
        .{ .mask = 0xFF, .instruction = 0x3F, .function = &ccf },
        .{ .mask = 0xFF, .instruction = 0xC3, .function = &jmp },
        .{ .mask = 0xFF, .instruction = 0xC9, .function = &ret },
        .{ .mask = 0xFF, .instruction = 0xCB, .function = &wide },
        .{ .mask = 0xFF, .instruction = 0xCD, .function = &call },
        .{ .mask = 0xFF, .instruction = 0xD9, .function = &reti },
        .{ .mask = 0xFF, .instruction = 0x76, .function = &hlt },
        .{ .mask = 0xFF, .instruction = 0xE0, .function = &sth_a_dir },
        .{ .mask = 0xFF, .instruction = 0xE2, .function = &sth_a_ind },
        .{ .mask = 0xFF, .instruction = 0xE8, .function = &add_sp_imm },
        .{ .mask = 0xFF, .instruction = 0xE9, .function = &jmp_hl },
        .{ .mask = 0xFF, .instruction = 0xEA, .function = &st_a_dir },
        .{ .mask = 0xFF, .instruction = 0xF0, .function = &ldh_a_dir },
        .{ .mask = 0xFF, .instruction = 0xF2, .function = &ldh_a_ind },
        .{ .mask = 0xFF, .instruction = 0xF3, .function = &di },
        .{ .mask = 0xFF, .instruction = 0xFA, .function = &ld_a_dir },
        .{ .mask = 0xFF, .instruction = 0xF8, .function = &mv_hl_sp_adj },
        .{ .mask = 0xFF, .instruction = 0xF9, .function = &mv_hl_sp },
        .{ .mask = 0xFF, .instruction = 0xFB, .function = &ei },
        .{ .mask = 0b11001111, .instruction = 0b00000001, .function = &ld16imm },
        .{ .mask = 0b11001111, .instruction = 0b00000010, .function = &st8ind },
        .{ .mask = 0b11000111, .instruction = 0b00000011, .function = &inc16 },
        .{ .mask = 0b11000110, .instruction = 0b00000100, .function = &inc8 },
        .{ .mask = 0b11000111, .instruction = 0b00000110, .function = &ld8imm },
        .{ .mask = 0b11001111, .instruction = 0b00001001, .function = &add_hl },
        .{ .mask = 0b11001111, .instruction = 0b00001010, .function = &ld8ind },
        .{ .mask = 0b11100111, .instruction = 0b00100000, .function = &jr_cond },
        .{ .mask = 0b11000000, .instruction = 0b01000000, .function = &mv },
        .{ .mask = 0b11000000, .instruction = 0b10000000, .function = &alu },
        .{ .mask = 0b11100111, .instruction = 0b11000000, .function = &ret_cond },
        .{ .mask = 0b11001111, .instruction = 0b11000001, .function = &pop },
        .{ .mask = 0b11100111, .instruction = 0b11000010, .function = &jmp_cond },
        .{ .mask = 0b11100111, .instruction = 0b11000100, .function = &call_cond },
        .{ .mask = 0b11001111, .instruction = 0b11000101, .function = &push },
        .{ .mask = 0b11000111, .instruction = 0b11000110, .function = &alu_imm },
        .{ .mask = 0b11000111, .instruction = 0b11000111, .function = &rst },
    };

    var table = [_]*const fn (self: *GBContext, opcode: u8) void{&todo} ** 0x100;

    @setEvalBranchQuota(1e5);
    for (0..0x100) |i| {
        for (opcode_masks) |opcode_mask| {
            if ((opcode_mask.mask & i) == opcode_mask.instruction) {
                table[i] = opcode_mask.function;
                break; //first masking applied
            }
        }
    }

    break :blk table;
};

fn todo(_: *GBContext, opcode: u8) void {
    if (@import("builtin").mode == .Debug)
        std.debug.panic("Instruction 0x{X:0>2} not implemented yet", .{opcode})
    else
        std.debug.print("Instruction 0x{X:0>2} not implemented yet\n", .{opcode});
}

fn nop(_: *GBContext, _: u8) void {}

fn hlt(self: *GBContext, _: u8) void {
    if (!self.IME and self.get_interrupt_pending() != 0) {
        const next_opcode = self.read_bus_internal(self.pc.read() +% 1);
        const next_is_rst = (next_opcode & 0b11000111) == 0b11000111;

        if (self.last_opcode == 0xFB and next_is_rst) {
            @panic("Interrupts are pending; do rst bug");
        } else if (self.last_opcode == 0xFB) {
            self.halt_ei_bug = true;
        } else {
            self.halt_bug = true;
        }
    } else {
        self.halted = true;
    }
}

fn stop(self: *GBContext, _: u8) void {
    self.timer.set_DIV(self, 0);

    if (self.io.speed.read_bit(1)) {
        self.io.speed.write_bit(1, false);
        const speed = self.io.speed.read_bit(7);
        self.io.speed.write_bit(7, !speed);
    } else {
        self.stopped = true;
    }
}

fn di(self: *GBContext, _: u8) void {
    self.IME_flipped = 0;
    self.IME = false;
}

fn ei(self: *GBContext, _: u8) void {
    if (!self.IME)
        self.IME_flipped = 1;
}

fn cpl(self: *GBContext, _: u8) void {
    const a = self.get_register8(.A);
    self.set_register8(.A, ~a);

    self.set_flags(.{ .n = true, .h = true });
}

fn ccf(self: *GBContext, _: u8) void {
    const flags = self.get_flags();
    self.set_flags(.{ .n = false, .h = false, .c = !flags.c });
}

fn scf(self: *GBContext, _: u8) void {
    self.set_flags(.{ .n = false, .h = false, .c = true });
}

fn rst(self: *GBContext, opcode: u8) void {
    self.tick();
    self.push16(self.pc);
    self.pc.write(opcode & 0x38);
}

fn daa(self: *GBContext, _: u8) void {
    const flags = self.get_flags();
    var a = self.get_register8(.A);
    var adjust: u8 = 0;
    var carry = flags.c;

    if (flags.h or (!flags.n and (a & 0x0F) > 0x09)) {
        adjust |= 0x06;
    }

    if (flags.c or (!flags.n and a > 0x99)) {
        adjust |= 0x60;
        carry = true;
    }

    if (flags.n) {
        a -%= adjust;
    } else {
        a +%= adjust;
    }

    self.set_register8(.A, a);
    self.set_flags(.{ .z = a == 0, .h = false, .c = carry });
}

fn sth_a_dir(self: *GBContext, _: u8) void {
    const register = GBContext.Register{
        .bytes = .{
            .l = self.read8_at_pc_inc(),
            .h = 0xff,
        },
    };

    self.write_bus(register.read(), self.get_register8(.A));
}

fn sth_a_ind(self: *GBContext, _: u8) void {
    var register = self.get_register16(.BC);
    register.bytes.h = 0xff;

    self.write_bus(register.read(), self.get_register8(.A));
}

fn st_a_dir(self: *GBContext, _: u8) void {
    const register = self.read16_at_pc_inc();

    self.write_bus(register.read(), self.get_register8(.A));
}

fn ldh_a_ind(self: *GBContext, _: u8) void {
    var register = self.get_register16(.BC);
    register.bytes.h = 0xff;

    const value = self.read_bus(register.read());
    self.set_register8(.A, value);
}

fn ldh_a_dir(self: *GBContext, _: u8) void {
    const register = GBContext.Register{
        .bytes = .{
            .l = self.read8_at_pc_inc(),
            .h = 0xff,
        },
    };

    const value = self.read_bus(register.read());
    self.set_register8(.A, value);
}

fn ld_a_dir(self: *GBContext, _: u8) void {
    const register = self.read16_at_pc_inc();

    const value = self.read_bus(register.read());
    self.set_register8(.A, value);
}

fn ld_sp_dir(self: *GBContext, _: u8) void {
    var register = self.read16_at_pc_inc();

    const sp = self.sp;

    self.write_bus(register.read(), sp.bytes.l);
    register.inc();
    self.write_bus(register.read(), sp.bytes.h);
}

fn jmp(self: *GBContext, _: u8) void {
    self.pc = self.read16_at_pc_inc();
    self.tick();
}

fn jmp_hl(self: *GBContext, _: u8) void {
    self.pc = self.get_register16(.HL);
}

fn jr(self: *GBContext, _: u8) void {
    const offset: i8 = @bitCast(self.read8_at_pc_inc());
    const addr: u32 = self.pc.read();
    var temp: i32 = @bitCast(addr);
    temp +%= offset;
    self.pc.write(@intCast(temp));
    self.tick();
}

fn jr_cond(self: *GBContext, opcode: u8) void {
    const flags = self.get_flags();

    const offset: i8 = @bitCast(self.read8_at_pc_inc());

    const condition = switch ((opcode >> 3) & 3) {
        0 => !flags.z,
        1 => flags.z,
        2 => !flags.c,
        3 => flags.c,
        else => unreachable,
    };

    if (condition) {
        const addr: u32 = self.pc.read();
        var temp: i32 = @bitCast(addr);
        temp +%= offset;
        self.pc.write(@intCast(temp));
        self.tick();
    }
}

fn jmp_cond(self: *GBContext, opcode: u8) void {
    const flags = self.get_flags();

    const new_pc = self.read16_at_pc_inc();

    const condition = switch ((opcode >> 3) & 3) {
        0 => !flags.z,
        1 => flags.z,
        2 => !flags.c,
        3 => flags.c,
        else => unreachable,
    };

    if (condition) {
        self.pc = new_pc;
        self.tick();
    }
}

fn call_cond(self: *GBContext, opcode: u8) void {
    const flags = self.get_flags();

    const new_pc = self.read16_at_pc_inc();

    const condition = switch ((opcode >> 3) & 3) {
        0 => !flags.z,
        1 => flags.z,
        2 => !flags.c,
        3 => flags.c,
        else => unreachable,
    };

    if (condition) {
        self.tick();
        self.push16(self.pc);
        self.pc = new_pc;
    }
}

fn call(self: *GBContext, _: u8) void {
    const register = self.read16_at_pc_inc();

    self.tick();

    self.push16(self.pc);

    self.pc = register;
}

fn ret_cond(self: *GBContext, opcode: u8) void {
    const flags = self.get_flags();

    const condition = switch ((opcode >> 3) & 3) {
        0 => !flags.z,
        1 => flags.z,
        2 => !flags.c,
        3 => flags.c,
        else => unreachable,
    };

    self.tick();
    if (condition) {
        self.pc = self.pop16();
        self.tick();
    }
}

fn ret(self: *GBContext, _: u8) void {
    self.pc = self.pop16();
    self.tick();
}

fn reti(self: *GBContext, _: u8) void {
    self.pc = self.pop16();

    self.IME = true;

    self.tick();
}

fn ld16imm(self: *GBContext, opcode: u8) void {
    const dest: GBContext.Register16 = switch ((opcode >> 4) & 3) {
        0 => .BC,
        1 => .DE,
        2 => .HL,
        3 => .SP,
        else => unreachable,
    };
    const register = GBContext.Register{ .bytes = .{
        .l = self.read8_at_pc_inc(),
        .h = self.read8_at_pc_inc(),
    } };

    self.set_register16(dest, register);
}

fn st8ind(self: *GBContext, opcode: u8) void {
    const addr_reg: GBContext.Register16 = switch ((opcode >> 4) & 3) {
        0 => .BC,
        1 => .DE,
        2 => .HL_INC,
        3 => .HL_DEC,
        else => unreachable,
    };
    const addr = self.get_register16(addr_reg).read();
    const value = self.get_register8(.A);

    self.write_bus(addr, value);
}

fn ld8ind(self: *GBContext, opcode: u8) void {
    const addr_reg: GBContext.Register16 = switch ((opcode >> 4) & 3) {
        0 => .BC,
        1 => .DE,
        2 => .HL_INC,
        3 => .HL_DEC,
        else => unreachable,
    };
    const addr = self.get_register16(addr_reg).read();
    const value = self.read_bus(addr);
    self.set_register8(.A, value);
}

fn ld8imm(self: *GBContext, opcode: u8) void {
    const dest: GBContext.Register8 = switch ((opcode >> 3) & 7) {
        0 => .B,
        1 => .C,
        2 => .D,
        3 => .E,
        4 => .H,
        5 => .L,
        6 => .HL_IND,
        7 => .A,
        else => unreachable,
    };
    const value = self.read8_at_pc_inc();
    self.set_register8(dest, value);
}

fn pop(self: *GBContext, opcode: u8) void {
    const destination: GBContext.Register16 = switch ((opcode >> 4) & 3) {
        0 => .BC,
        1 => .DE,
        2 => .HL,
        3 => .AF,
        else => unreachable,
    };

    self.set_register16(destination, self.pop16());
}

fn inc16(self: *GBContext, opcode: u8) void {
    const reg: GBContext.Register16 = switch ((opcode >> 4) & 3) {
        0 => .BC,
        1 => .DE,
        2 => .HL,
        3 => .SP,
        else => unreachable,
    };

    var register = self.get_register16(reg);
    if (opcode & 8 == 0) {
        register.inc();
    } else {
        register.dec();
    }
    self.set_register16(reg, register);
    self.tick();
}

fn add_hl(self: *GBContext, opcode: u8) void {
    const reg: GBContext.Register16 = switch ((opcode >> 4) & 3) {
        0 => .BC,
        1 => .DE,
        2 => .HL,
        3 => .SP,
        else => unreachable,
    };

    const a = self.get_register16(.HL);
    const b = self.get_register16(reg);

    const result = @addWithOverflow(a.read(), b.read());

    self.hl.value = result[0];

    self.set_flags(.{ .n = false, .c = result[1] == 1, .h = ((a.read() & 0x0FFF) + (b.read() & 0x0FFF)) > 0x0FFF });

    self.tick();
}

fn inc8(self: *GBContext, opcode: u8) void {
    const reg: GBContext.Register8 = switch ((opcode >> 3) & 7) {
        0 => .B,
        1 => .C,
        2 => .D,
        3 => .E,
        4 => .H,
        5 => .L,
        6 => .HL_IND,
        7 => .A,
        else => unreachable,
    };

    var value = self.get_register8(reg);
    var h: bool = undefined;

    if (opcode & 1 == 0) {
        value +%= 1;
        h = (value & 0xf) == 0;
    } else {
        value -%= 1;
        h = (value & 0xf) == 0xf;
    }
    self.set_register8(reg, value);
    self.set_flags(.{ .z = value == 0, .n = opcode & 1 == 1, .h = h });
}

fn push(self: *GBContext, opcode: u8) void {
    const destination: GBContext.Register16 = switch ((opcode >> 4) & 3) {
        0 => .BC,
        1 => .DE,
        2 => .HL,
        3 => .AF,
        else => unreachable,
    };
    self.tick();
    self.push16(self.get_register16(destination));
}

fn mv_hl_sp_adj(self: *GBContext, _: u8) void {
    const offset: i8 = @bitCast(self.read8_at_pc_inc());
    const sp: i16 = @bitCast(self.sp.read());
    const hl = sp +% offset;

    const check_sp: u16 = @bitCast(sp & 0xFF);
    const check_off: u8 = @bitCast(offset);

    self.hl.write(@bitCast(hl));

    self.set_flags(.{
        .z = false,
        .n = false,
        .c = check_sp + check_off > 0xFF,
        .h = (check_sp & 0x0F) + (check_off & 0x0F) > 0x0F,
    });

    self.tick();
}

fn add_sp_imm(self: *GBContext, _: u8) void {
    const offset: i8 = @bitCast(self.read8_at_pc_inc());
    const sp: i16 = @bitCast(self.sp.read());
    const new_sp = sp +% offset;

    const check_sp: u16 = @bitCast(sp & 0xFF);
    const check_off: u8 = @bitCast(offset);

    self.sp.write(@bitCast(new_sp));

    self.set_flags(.{
        .z = false,
        .n = false,
        .c = check_sp + check_off > 0xFF,
        .h = (check_sp & 0x0F) + (check_off & 0x0F) > 0x0F,
    });

    self.tick();
    self.tick();
}

fn mv_hl_sp(self: *GBContext, _: u8) void {
    self.sp = self.hl;
    self.tick();
}

fn mv(self: *GBContext, opcode: u8) void {
    const origin: GBContext.Register8 = switch (opcode & 7) {
        0 => .B,
        1 => .C,
        2 => .D,
        3 => .E,
        4 => .H,
        5 => .L,
        6 => .HL_IND,
        7 => .A,
        else => unreachable,
    };
    const dest: GBContext.Register8 = switch ((opcode >> 3) & 7) {
        0 => .B,
        1 => .C,
        2 => .D,
        3 => .E,
        4 => .H,
        5 => .L,
        6 => .HL_IND,
        7 => .A,
        else => unreachable,
    };
    const register = self.get_register8(origin);
    self.set_register8(dest, register);
}

fn alu(self: *GBContext, opcode: u8) void {
    const operand: GBContext.Register8 = switch (opcode & 7) {
        0 => .B,
        1 => .C,
        2 => .D,
        3 => .E,
        4 => .H,
        5 => .L,
        6 => .HL_IND,
        7 => .A,
        else => unreachable,
    };

    switch (@as(u3, @truncate(opcode >> 3))) {
        0 => add(self, operand),
        1 => adc(self, operand),
        2 => sub(self, operand),
        3 => sbc(self, operand),
        4 => _and(self, operand),
        5 => xor(self, operand),
        6 => _or(self, operand),
        7 => cp(self, operand),
    }
}

fn alu_imm(self: *GBContext, opcode: u8) void {
    self.internal = self.read8_at_pc_inc();

    switch (@as(u3, @truncate(opcode >> 3))) {
        0 => add(self, .internal),
        1 => adc(self, .internal),
        2 => sub(self, .internal),
        3 => sbc(self, .internal),
        4 => _and(self, .internal),
        5 => xor(self, .internal),
        6 => _or(self, .internal),
        7 => cp(self, .internal),
    }
}

fn rla(self: *GBContext, _: u8) void {
    const a = self.get_register8(.A);

    const carry = (a >> 7) & 1;

    self.set_register8(.A, (a << 1) | @as(u1, @bitCast(self.get_flags().c)));

    self.set_flags(.{
        .z = false,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn rlca(self: *GBContext, _: u8) void {
    const a = self.get_register8(.A);

    const carry = (a >> 7) & 1;

    self.set_register8(.A, (a << 1) | carry);

    self.set_flags(.{
        .z = false,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn add(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(.A);
    const b = self.get_register8(operand);

    const result = @addWithOverflow(a, b);

    self.set_register8(.A, result[0]);

    self.set_flags(.{
        .z = result[0] == 0,
        .n = false,
        .c = result[1] == 1,
        .h = (a & 0xf) + (b & 0xf) > 0xf,
    });
}

fn adc(self: *GBContext, operand: GBContext.Register8) void {
    const a: u16 = self.get_register8(.A);
    const b: u16 = self.get_register8(operand);

    const result = a + b + @as(u1, @bitCast(self.get_flags().c));
    const h_result = (a & 0xf) + (b & 0xf) + @as(u1, @bitCast(self.get_flags().c));

    self.set_register8(.A, @truncate(result));

    self.set_flags(.{
        .z = (result & 0xFF) == 0,
        .n = false,
        .c = result > 0xFF,
        .h = h_result > 0xF,
    });
}

fn sub(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(.A);
    const b = self.get_register8(operand);

    self.set_register8(.A, a -% b);

    self.set_flags(.{
        .z = a == b,
        .n = true,
        .c = a < b,
        .h = (a & 0xF) < (b & 0xF),
    });
}

fn sbc(self: *GBContext, operand: GBContext.Register8) void {
    const a: u16 = self.get_register8(.A);
    const b: u16 = self.get_register8(operand);

    const result = a -% b -% @as(u1, @bitCast(self.get_flags().c));
    const h_result = (a & 0xf) -% (b & 0xf) -% @as(u1, @bitCast(self.get_flags().c));

    self.set_register8(.A, @truncate(result));

    self.set_flags(.{
        .z = (result & 0xFF) == 0,
        .n = true,
        .c = result > 0xFF,
        .h = h_result > 0xF,
    });
}

fn _and(self: *GBContext, operand: GBContext.Register8) void {
    var a = self.get_register8(.A);
    const b = self.get_register8(operand);

    a &= b;

    self.set_register8(.A, a);

    self.set_flags(.{
        .z = a == 0,
        .n = false,
        .c = false,
        .h = true,
    });
}

fn xor(self: *GBContext, operand: GBContext.Register8) void {
    var a = self.get_register8(.A);
    const b = self.get_register8(operand);

    a ^= b;

    self.set_register8(.A, a);

    self.set_flags(.{
        .z = a == 0,
        .n = false,
        .c = false,
        .h = false,
    });
}

fn _or(self: *GBContext, operand: GBContext.Register8) void {
    var a = self.get_register8(.A);
    const b = self.get_register8(operand);

    a |= b;

    self.set_register8(.A, a);

    self.set_flags(.{
        .z = a == 0,
        .n = false,
        .c = false,
        .h = false,
    });
}

fn cp(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(.A);
    const b = self.get_register8(operand);

    self.set_flags(.{
        .z = a == b,
        .n = true,
        .c = a < b,
        .h = (a & 0xF) < (b & 0xF),
    });
}

fn rra(self: *GBContext, _: u8) void {
    const a = self.get_register8(.A);

    const carry = a & 1;
    const old_carry: u8 = @as(u1, @bitCast(self.get_flags().c));

    self.set_register8(.A, (a >> 1) | (old_carry << 7));

    self.set_flags(.{
        .z = false,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn rrca(self: *GBContext, _: u8) void {
    const a = self.get_register8(.A);

    const carry = a & 1;

    self.set_register8(.A, (a >> 1) | (carry << 7));

    self.set_flags(.{
        .z = false,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn wide(self: *GBContext, _: u8) void {
    const opcode = self.read8_at_pc_inc();
    const operand: GBContext.Register8 = switch (opcode & 7) {
        0 => .B,
        1 => .C,
        2 => .D,
        3 => .E,
        4 => .H,
        5 => .L,
        6 => .HL_IND,
        7 => .A,
        else => unreachable,
    };

    switch (opcode) {
        0x00...0x07 => rlc(self, operand),
        0x08...0x0F => rrc(self, operand),
        0x10...0x17 => rl(self, operand),
        0x18...0x1F => rr(self, operand),
        0x20...0x27 => sla(self, operand),
        0x28...0x2F => sra(self, operand),
        0x30...0x37 => swap(self, operand),
        0x38...0x3F => srl(self, operand),
        0x40...0x7f => bit(self, operand, @truncate(opcode >> 3)),
        0x80...0xbf => res(self, operand, @truncate(opcode >> 3)),
        0xc0...0xff => set(self, operand, @truncate(opcode >> 3)),
    }
}

fn rlc(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(operand);

    const carry = (a >> 7) & 1;

    self.set_register8(operand, (a << 1) | carry);

    self.set_flags(.{
        .z = a == 0,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn rrc(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(operand);

    const carry = a & 1;

    self.set_register8(operand, (a >> 1) | (carry << 7));

    self.set_flags(.{
        .z = a == 0,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn rl(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(operand);

    const carry = (a >> 7) & 1;
    const old_carry: u8 = @as(u1, @bitCast(self.get_flags().c));

    const result = (a << 1) | old_carry;

    self.set_register8(operand, result);

    self.set_flags(.{
        .z = result == 0,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn rr(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(operand);

    const carry = a & 1;
    const old_carry: u8 = @as(u1, @bitCast(self.get_flags().c));

    const result = (a >> 1) | (old_carry << 7);

    self.set_register8(operand, result);

    self.set_flags(.{
        .z = result == 0,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn sla(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(operand);

    const carry = (a >> 7) & 1;
    const result = a << 1;

    self.set_register8(operand, result);

    self.set_flags(.{
        .z = result == 0,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn sra(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(operand);

    const carry = a & 1;
    const result = ((a >> 1) & 0x7F) | (a & 0x80);

    self.set_register8(operand, result);

    self.set_flags(.{
        .z = result == 0,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn srl(self: *GBContext, operand: GBContext.Register8) void {
    const a = self.get_register8(operand);

    const carry = a & 1;
    const result = ((a >> 1) & 0x7F);

    self.set_register8(operand, result);

    self.set_flags(.{
        .z = result == 0,
        .n = false,
        .h = false,
        .c = carry == 1,
    });
}

fn swap(self: *GBContext, operand: GBContext.Register8) void {
    const HalfByte = packed struct(u8) { l: u4 = 0, h: u4 = 0 };

    var value: HalfByte = @bitCast(self.get_register8(operand));
    const t = value.l;
    value.l = value.h;
    value.h = t;

    const raw_value: u8 = @bitCast(value);

    self.set_register8(operand, raw_value);

    self.set_flags(.{
        .z = raw_value == 0,
        .n = false,
        .h = false,
        .c = false,
    });
}

fn bit(self: *GBContext, operand: GBContext.Register8, pos: u3) void {
    const a = self.get_register8(operand);
    const mask = @as(u8, 1) << pos;

    self.set_flags(.{
        .z = (a & mask) == 0,
        .n = false,
        .h = true,
    });
}

fn res(self: *GBContext, operand: GBContext.Register8, pos: u3) void {
    const a = self.get_register8(operand);
    const mask = ~(@as(u8, 1) << pos);

    self.set_register8(operand, a & mask);
}

fn set(self: *GBContext, operand: GBContext.Register8, pos: u3) void {
    const a = self.get_register8(operand);
    const mask = @as(u8, 1) << pos;

    self.set_register8(operand, a | mask);
}
