import 'package:flutter_6502_processor_emulator/emulator/bus.dart';
import 'package:flutter_6502_processor_emulator/emulator/flags.dart';
import 'package:flutter_6502_processor_emulator/emulator/instruction.dart';

class Cpu {
  Cpu(this.bus) {
    lookup = _getInstructions();

    reset();
  }

  final Bus bus;
  final Flags flags = Flags();

  late final List<Instruction> lookup;

  int a = 0x00;
  int x = 0x00;
  int y = 0x00;
  int pc = 0x0000;
  int sp = 0x00;

  int fetched = 0x00;
  int absAddress = 0x0000;
  int relAddress = 0x00;
  int opCode = 0x00;

  int cycles = 0;
  int clockCount = 0;

  void reset() {
    absAddress = 0xFFFC;

    final int low = read(absAddress);
    final int high = read(absAddress + 1);

    pc = (high << 8) | low;

    a = 0x00;
    x = 0x00;
    y = 0x00;
    sp = 0xFD;

    fetched = 0x00;
    absAddress = 0x0000;
    relAddress = 0x00;

    cycles = 8;
  }

  void irq() {
    if (flags.i) {
      write(0x0100 + sp, (pc >> 8) & 0x00FF);
      sp--;
      write(0x0100 + sp, pc & 0x00FF);
      sp--;

      flags
        ..b = false
        ..u = true
        ..i = true;

      write(0x0100 + sp, flags.status);
      sp--;

      absAddress = 0xFFFE;
      final int low = read(absAddress);
      final int high = read(absAddress + 1);
      pc = (high << 8) | low;

      cycles = 7;
    }
  }

  void nmi() {
    write(0x0100 + sp, (pc >> 8) & 0x00FF);
    sp--;
    write(0x0100 + sp, pc & 0x00FF);
    sp--;

    flags
      ..b = false
      ..u = true
      ..i = true;

    write(0x0100 + sp, flags.status);
    sp--;

    absAddress = 0xFFFA;
    final int low = read(absAddress);
    final int high = read(absAddress + 1);
    pc = (high << 8) | low;

    cycles = 8;
  }

  void clock() {
    if (cycles == 0) {
      opCode = read(pc);
      flags.u = true;
      pc++;
      cycles = lookup[opCode].cycles;

      final int additionalCycle1 = lookup[opCode].addressMode();
      final int additionalCycle2 = lookup[opCode].operate();

      cycles += additionalCycle1 & additionalCycle2;
    }

    clockCount++;
    cycles--;
  }

  int fetch() {
    if (lookup[opCode].addressMode != imp) {
      fetched = read(absAddress);
    }

    return fetched;
  }

  bool complete() => cycles == 0;

  int read(int address) => bus.read(address);

  void write(int address, int data) => bus.write(address, data);

  int imp() {
    fetched = a;

    return 0;
  }

  int imm() {
    absAddress = pc++;

    return 0;
  }

  int zp0() {
    absAddress = read(pc);
    pc++;
    absAddress &= 0x00FF;

    return 0;
  }

  int zpx() {
    absAddress = read(pc) + x;
    pc++;
    absAddress &= 0x00FF;

    return 0;
  }

  int zpy() {
    absAddress = read(pc) + y;
    pc++;
    absAddress &= 0x00FF;

    return 0;
  }

  int rel() {
    relAddress = read(pc);
    pc++;

    if (relAddress & 0x80 != 0) {
      relAddress |= 0xFF00;
    }

    return 0;
  }

  int abs() {
    final int low = read(pc);
    pc++;
    final int high = read(pc);
    pc++;

    absAddress = (high << 8) | low;

    return 0;
  }

  int abx() {
    final int low = read(pc);
    pc++;
    final int high = read(pc);
    pc++;

    absAddress = (high << 8) | low;
    absAddress += x;

    return ((absAddress & 0xFF00) != (high << 8)) ? 1 : 0;
  }

  int aby() {
    final int low = read(pc);
    pc++;
    final int high = read(pc);
    pc++;

    absAddress = (high << 8) | low;
    absAddress += y;

    return ((absAddress & 0xFF00) != (high << 8)) ? 1 : 0;
  }

  int ind() {
    final int pointerLow = read(pc);
    pc++;
    final int pointerHigh = read(pc);
    pc++;

    final int pointer = (pointerHigh << 8) | pointerLow;

    if (pointerLow == 0x00FF) {
      absAddress = (read(pointer & 0xFF00) << 8) | read(pointer);
    } else {
      absAddress = (read(pointer + 1) << 8) | read(pointer);
    }

    return 0;
  }

  int izx() {
    final int tempPc = read(pc);
    pc++;

    final int low = read((tempPc + x) & 0x00FF);
    final int high = read((tempPc + x + 1) & 0x00FF);

    absAddress = (high << 8) | low;

    return 0;
  }

  int izy() {
    final int tempPc = read(pc);
    pc++;

    final int low = read(tempPc & 0x00FF);
    final int high = read((tempPc + 1) & 0x00FF);

    absAddress = (high << 8) | low;
    absAddress += y;

    return ((absAddress & 0xFF00) != (high << 8)) ? 1 : 0;
  }

  int adc() {
    fetch();

    final int temp = a + fetched + (flags.c ? 1 : 0);

    flags
      ..c = temp > 255
      ..z = (temp & 0x00FF) == 0
      ..v = ((~(a ^ fetched) & (a ^ temp)) & 0x0080) != 0
      ..n = (temp & 0x0080) != 0;

    a = temp & 0x00FF;

    return 1;
  }

  int sbc() {
    fetch();

    final int value = fetched ^ 0x00FF;
    final int temp = a + value + (flags.c ? 1 : 0);

    flags
      ..c = temp & 0xFF00 != 0
      ..z = (temp & 0x00FF) == 0
      ..v = ((temp ^ a) & (temp ^ value) & 0x0080) != 0
      ..n = (temp & 0x0080) != 0;

    a = temp & 0x00FF;

    return 1;
  }

  int and() {
    fetch();

    a = a & fetched;

    flags
      ..z = a == 0x00
      ..n = (a & 0x80) != 0;

    return 1;
  }

  int asl() {
    fetch();

    final int temp = fetched << 1;

    flags
      ..c = (temp & 0xFF00) > 0
      ..z = (temp & 0x00FF) == 0x00
      ..n = (a & 0x80) != 0;

    if (lookup[opCode].addressMode == imp) {
      a = temp & 0x00FF;
    } else {
      write(absAddress, temp & 0x00FF);
    }

    return 0;
  }

  int bcc() {
    if (!flags.c) {
      _branch();
    }

    return 0;
  }

  int bcs() {
    if (flags.c) {
      _branch();
    }

    return 0;
  }

  int beq() {
    if (flags.z) {
      _branch();
    }

    return 0;
  }

  int bit() {
    fetch();

    final int temp = a & fetched;

    flags
      ..z = (temp & 0x00FF) == 0x00
      ..n = (fetched & (1 << 7)) != 0
      ..v = (fetched & (1 << 6)) != 0;

    return 0;
  }

  int bmi() {
    if (flags.n) {
      _branch();
    }

    return 0;
  }

  int bne() {
    if (!flags.z) {
      _branch();
    }

    return 0;
  }

  int bpl() {
    if (!flags.n) {
      _branch();
    }

    return 0;
  }

  int brk() {
    pc++;

    flags.i = true;

    write(0x0100 + sp, (pc >> 8) & 0x00FF);
    sp--;
    write(0x0100 + sp, pc & 0x00FF);
    sp--;

    flags.b = true;
    write(0x0100 + sp, flags.status);
    sp--;
    flags.b = false;

    pc = read(0xFFFE) | (read(0xFFFF) << 8);

    return 0;
  }

  int bvc() {
    if (!flags.v) {
      _branch();
    }

    return 0;
  }

  int bvs() {
    if (flags.v) {
      _branch();
    }

    return 0;
  }

  int clc() {
    flags.c = false;

    return 0;
  }

  int cld() {
    flags.d = false;

    return 0;
  }

  int cli() {
    flags.i = false;

    return 0;
  }

  int clv() {
    flags.v = false;

    return 0;
  }

  int cmp() {
    fetch();

    final int temp = a - fetched;

    flags
      ..c = a >= fetched
      ..z = (temp & 0x00FF) == 0x0000
      ..n = (temp & 0x0080) != 0;

    return 1;
  }

  int cpx() {
    fetch();

    final int temp = x - fetched;

    flags
      ..c = x >= fetched
      ..z = (temp & 0x00FF) == 0x0000
      ..n = (temp & 0x0080) != 0;

    return 0;
  }

  int cpy() {
    fetch();

    final int temp = y - fetched;

    flags
      ..c = y >= fetched
      ..z = (temp & 0x00FF) == 0x0000
      ..n = (temp & 0x0080) != 0;

    return 0;
  }

  int dec() {
    fetch();

    final int temp = fetched - 1;

    write(absAddress, temp & 0x00FF);

    flags
      ..z = (temp & 0x00FF) == 0x0000
      ..n = (temp & 0x0080) != 0;

    return 0;
  }

  int dex() {
    x--;

    flags
      ..z = (x & 0xFF) == 0x00
      ..n = (x & 0x80) != 0;

    return 0;
  }

  int dey() {
    y--;

    flags
      ..z = (y & 0xFF) == 0x00
      ..n = (y & 0x80) != 0;

    return 0;
  }

  int eor() {
    fetch();

    a = a ^ fetched;

    flags
      ..z = (a & 0xFF) == 0x00
      ..n = (a & 0x80) != 0;

    return 1;
  }

  int inc() {
    fetch();

    final int temp = fetched + 1;

    write(absAddress, temp & 0x00FF);

    flags
      ..z = (temp & 0xFF) == 0x00
      ..n = (temp & 0x80) != 0;

    return 0;
  }

  int inx() {
    x++;

    flags
      ..z = (x & 0xFF) == 0x00
      ..n = (x & 0x80) != 0;

    return 0;
  }

  int iny() {
    y++;

    flags
      ..z = (y & 0xFF) == 0x00
      ..n = (y & 0x80) != 0;

    return 0;
  }

  int jmp() {
    pc = absAddress;

    return 0;
  }

  int jsr() {
    pc--;

    write(0x0100 + sp, (pc >> 8) & 0x00FF);
    sp--;
    write(0x0100 + sp, pc & 0x00FF);
    sp--;

    pc = absAddress;

    return 0;
  }

  int lda() {
    fetch();

    a = fetched;

    flags
      ..z = (a & 0xFF) == 0x00
      ..n = (a & 0x80) != 0;

    return 1;
  }

  int ldx() {
    fetch();

    x = fetched;

    flags
      ..z = (x & 0xFF) == 0x00
      ..n = (x & 0x80) != 0;

    return 1;
  }

  int ldy() {
    fetch();

    y = fetched;

    flags
      ..z = (y & 0xFF) == 0x00
      ..n = (y & 0x80) != 0;

    return 1;
  }

  int lsr() {
    fetch();

    flags.c = (fetched & 0x0001) != 0;
    final int temp = fetched >> 1;
    flags
      ..z = (temp & 0x00FF) == 0x0000
      ..n = (temp & 0x0080) != 0;

    if (lookup[opCode].addressMode == imp) {
      a = temp & 0x00FF;
    } else {
      write(absAddress, temp & 0x00FF);
    }

    return 0;
  }

  int nop() {
    switch (opCode) {
      case 0x1C:
      case 0x3C:
      case 0x5C:
      case 0x7C:
      case 0xDC:
      case 0xFC:
        return 1;

      default:
        return 0;
    }
  }

  int ora() {
    fetch();
    a = a | fetched;

    flags
      ..z = (a & 0xFF) == 0x00
      ..n = (a & 0x80) != 0;

    return 1;
  }

  int pha() {
    write(0x0100 + sp, a);
    sp--;

    return 0;
  }

  int php() {
    flags
      ..b = true
      ..u = true;

    write(0x0100 + sp, flags.status);

    flags
      ..b = false
      ..u = false;

    sp--;

    return 0;
  }

  int pla() {
    sp++;

    a = read(0x0100 + sp);

    flags
      ..z = (a & 0xFF) == 0x00
      ..n = (a & 0x80) != 0;

    return 0;
  }

  int plp() {
    sp++;
    flags
      ..status = read(0x0100 + sp)
      ..u = true;

    return 0;
  }

  int rol() {
    fetch();

    final int temp = (fetched << 1) | (flags.c ? 1 : 0);

    flags
      ..c = (temp & 0xFF00) != 0
      ..z = (temp & 0x00FF) == 0x0000
      ..n = (temp & 0x0080) != 0;

    if (lookup[opCode].addressMode == imp) {
      a = temp & 0x00FF;
    } else {
      write(absAddress, temp & 0x00FF);
    }

    return 0;
  }

  int ror() {
    fetch();

    final int temp = ((flags.c ? 1 : 0) << 7) | (fetched >> 1);

    flags
      ..c = (fetched & 0x01) != 0
      ..z = (temp & 0x00FF) == 0x00
      ..n = (temp & 0x0080) != 0;

    if (lookup[opCode].addressMode == imp) {
      a = temp & 0x00FF;
    } else {
      write(absAddress, temp & 0x00FF);
    }

    return 0;
  }

  int rti() {
    sp++;

    flags
      ..status = read(0x0100 + sp)
      ..b &= !flags.b
      ..u &= !flags.u;

    sp++;
    pc = read(0x0100 + sp);
    sp++;

    pc |= read(0x0100 + sp) << 8;

    return 0;
  }

  int rts() {
    sp++;
    pc = read(0x0100 + sp);
    sp++;
    pc |= read(0x0100 + sp) << 8;

    pc++;

    return 0;
  }

  int sec() {
    flags.c = true;

    return 0;
  }

  int sed() {
    flags.d = true;

    return 0;
  }

  int sei() {
    flags.i = true;

    return 0;
  }

  int sta() {
    write(absAddress, a);

    return 0;
  }

  int stx() {
    write(absAddress, x);

    return 0;
  }

  int sty() {
    write(absAddress, y);

    return 0;
  }

  int tax() {
    x = a;

    flags
      ..z = x == 0x00
      ..n = (x & 0x80 != 0);

    return 0;
  }

  int tay() {
    y = a;

    flags
      ..z = y == 0x00
      ..n = (y & 0x80 != 0);

    return 0;
  }

  int tsx() {
    x = sp;

    flags
      ..z = x == 0x00
      ..n = (x & 0x80 != 0);

    return 0;
  }

  int txa() {
    a = x;

    flags
      ..z = a == 0x00
      ..n = (a & 0x80 != 0);

    return 0;
  }

  int txs() {
    sp = x;

    return 0;
  }

  int tya() {
    a = y;

    flags
      ..z = a == 0x00
      ..n = (a & 0x80 != 0);

    return 0;
  }

  int xxx() => 0;

  void _branch() {
    cycles++;

    absAddress = (pc + relAddress) & bus.ram.size;

    if ((absAddress & 0xFF00) != (pc & 0xFF00)) {
      cycles++;
    }

    pc = absAddress;
  }

  List<Instruction> _getInstructions() => <Instruction>[
        Instruction('BRK', brk, imm, 7),
        Instruction('ORA', ora, izx, 6),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('???', nop, imp, 3),
        Instruction('ORA', ora, zp0, 3),
        Instruction('ASL', asl, zp0, 5),
        Instruction('???', xxx, imp, 5),
        Instruction('PHP', php, imp, 3),
        Instruction('ORA', ora, imm, 2),
        Instruction('ASL', asl, imp, 2),
        Instruction('???', xxx, imp, 2),
        Instruction('???', nop, imp, 4),
        Instruction('ORA', ora, abs, 4),
        Instruction('ASL', asl, abs, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('BPL', bpl, rel, 2),
        Instruction('ORA', ora, izy, 5),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('???', nop, imp, 4),
        Instruction('ORA', ora, zpx, 4),
        Instruction('ASL', asl, zpx, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('CLC', clc, imp, 2),
        Instruction('ORA', ora, aby, 4),
        Instruction('???', nop, imp, 2),
        Instruction('???', xxx, imp, 7),
        Instruction('???', nop, imp, 4),
        Instruction('ORA', ora, abx, 4),
        Instruction('ASL', asl, abx, 7),
        Instruction('???', xxx, imp, 7),
        Instruction('JSR', jsr, abs, 6),
        Instruction('AND', and, izx, 6),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('BIT', bit, zp0, 3),
        Instruction('AND', and, zp0, 3),
        Instruction('ROL', rol, zp0, 5),
        Instruction('???', xxx, imp, 5),
        Instruction('PLP', plp, imp, 4),
        Instruction('AND', and, imm, 2),
        Instruction('ROL', rol, imp, 2),
        Instruction('???', xxx, imp, 2),
        Instruction('BIT', bit, abs, 4),
        Instruction('AND', and, abs, 4),
        Instruction('ROL', rol, abs, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('BMI', bmi, rel, 2),
        Instruction('AND', and, izy, 5),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('???', nop, imp, 4),
        Instruction('AND', and, zpx, 4),
        Instruction('ROL', rol, zpx, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('SEC', sec, imp, 2),
        Instruction('AND', and, aby, 4),
        Instruction('???', nop, imp, 2),
        Instruction('???', xxx, imp, 7),
        Instruction('???', nop, imp, 4),
        Instruction('AND', and, abx, 4),
        Instruction('ROL', rol, abx, 7),
        Instruction('???', xxx, imp, 7),
        Instruction('RTI', rti, imp, 6),
        Instruction('EOR', eor, izx, 6),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('???', nop, imp, 3),
        Instruction('EOR', eor, zp0, 3),
        Instruction('LSR', lsr, zp0, 5),
        Instruction('???', xxx, imp, 5),
        Instruction('PHA', pha, imp, 3),
        Instruction('EOR', eor, imm, 2),
        Instruction('LSR', lsr, imp, 2),
        Instruction('???', xxx, imp, 2),
        Instruction('JMP', jmp, abs, 3),
        Instruction('EOR', eor, abs, 4),
        Instruction('LSR', lsr, abs, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('BVC', bvc, rel, 2),
        Instruction('EOR', eor, izy, 5),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('???', nop, imp, 4),
        Instruction('EOR', eor, zpx, 4),
        Instruction('LSR', lsr, zpx, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('CLI', cli, imp, 2),
        Instruction('EOR', eor, aby, 4),
        Instruction('???', nop, imp, 2),
        Instruction('???', xxx, imp, 7),
        Instruction('???', nop, imp, 4),
        Instruction('EOR', eor, abx, 4),
        Instruction('LSR', lsr, abx, 7),
        Instruction('???', xxx, imp, 7),
        Instruction('RTS', rts, imp, 6),
        Instruction('ADC', adc, izx, 6),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('???', nop, imp, 3),
        Instruction('ADC', adc, zp0, 3),
        Instruction('ROR', ror, zp0, 5),
        Instruction('???', xxx, imp, 5),
        Instruction('PLA', pla, imp, 4),
        Instruction('ADC', adc, imm, 2),
        Instruction('ROR', ror, imp, 2),
        Instruction('???', xxx, imp, 2),
        Instruction('JMP', jmp, ind, 5),
        Instruction('ADC', adc, abs, 4),
        Instruction('ROR', ror, abs, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('BVS', bvs, rel, 2),
        Instruction('ADC', adc, izy, 5),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('???', nop, imp, 4),
        Instruction('ADC', adc, zpx, 4),
        Instruction('ROR', ror, zpx, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('SEI', sei, imp, 2),
        Instruction('ADC', adc, aby, 4),
        Instruction('???', nop, imp, 2),
        Instruction('???', xxx, imp, 7),
        Instruction('???', nop, imp, 4),
        Instruction('ADC', adc, abx, 4),
        Instruction('ROR', ror, abx, 7),
        Instruction('???', xxx, imp, 7),
        Instruction('???', nop, imp, 2),
        Instruction('STA', sta, izx, 6),
        Instruction('???', nop, imp, 2),
        Instruction('???', xxx, imp, 6),
        Instruction('STY', sty, zp0, 3),
        Instruction('STA', sta, zp0, 3),
        Instruction('STX', stx, zp0, 3),
        Instruction('???', xxx, imp, 3),
        Instruction('DEY', dey, imp, 2),
        Instruction('???', nop, imp, 2),
        Instruction('TXA', txa, imp, 2),
        Instruction('???', xxx, imp, 2),
        Instruction('STY', sty, abs, 4),
        Instruction('STA', sta, abs, 4),
        Instruction('STX', stx, abs, 4),
        Instruction('???', xxx, imp, 4),
        Instruction('BCC', bcc, rel, 2),
        Instruction('STA', sta, izy, 6),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 6),
        Instruction('STY', sty, zpx, 4),
        Instruction('STA', sta, zpx, 4),
        Instruction('STX', stx, zpy, 4),
        Instruction('???', xxx, imp, 4),
        Instruction('TYA', tya, imp, 2),
        Instruction('STA', sta, aby, 5),
        Instruction('TXS', txs, imp, 2),
        Instruction('???', xxx, imp, 5),
        Instruction('???', nop, imp, 5),
        Instruction('STA', sta, abx, 5),
        Instruction('???', xxx, imp, 5),
        Instruction('???', xxx, imp, 5),
        Instruction('LDY', ldy, imm, 2),
        Instruction('LDA', lda, izx, 6),
        Instruction('LDX', ldx, imm, 2),
        Instruction('???', xxx, imp, 6),
        Instruction('LDY', ldy, zp0, 3),
        Instruction('LDA', lda, zp0, 3),
        Instruction('LDX', ldx, zp0, 3),
        Instruction('???', xxx, imp, 3),
        Instruction('TAY', tay, imp, 2),
        Instruction('LDA', lda, imm, 2),
        Instruction('TAX', tax, imp, 2),
        Instruction('???', xxx, imp, 2),
        Instruction('LDY', ldy, abs, 4),
        Instruction('LDA', lda, abs, 4),
        Instruction('LDX', ldx, abs, 4),
        Instruction('???', xxx, imp, 4),
        Instruction('BCS', bcs, rel, 2),
        Instruction('LDA', lda, izy, 5),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 5),
        Instruction('LDY', ldy, zpx, 4),
        Instruction('LDA', lda, zpx, 4),
        Instruction('LDX', ldx, zpy, 4),
        Instruction('???', xxx, imp, 4),
        Instruction('CLV', clv, imp, 2),
        Instruction('LDA', lda, aby, 4),
        Instruction('TSX', tsx, imp, 2),
        Instruction('???', xxx, imp, 4),
        Instruction('LDY', ldy, abx, 4),
        Instruction('LDA', lda, abx, 4),
        Instruction('LDX', ldx, aby, 4),
        Instruction('???', xxx, imp, 4),
        Instruction('CPY', cpy, imm, 2),
        Instruction('CMP', cmp, izx, 6),
        Instruction('???', nop, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('CPY', cpy, zp0, 3),
        Instruction('CMP', cmp, zp0, 3),
        Instruction('DEC', dec, zp0, 5),
        Instruction('???', xxx, imp, 5),
        Instruction('INY', iny, imp, 2),
        Instruction('CMP', cmp, imm, 2),
        Instruction('DEX', dex, imp, 2),
        Instruction('???', xxx, imp, 2),
        Instruction('CPY', cpy, abs, 4),
        Instruction('CMP', cmp, abs, 4),
        Instruction('DEC', dec, abs, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('BNE', bne, rel, 2),
        Instruction('CMP', cmp, izy, 5),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('???', nop, imp, 4),
        Instruction('CMP', cmp, zpx, 4),
        Instruction('DEC', dec, zpx, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('CLD', cld, imp, 2),
        Instruction('CMP', cmp, aby, 4),
        Instruction('NOP', nop, imp, 2),
        Instruction('???', xxx, imp, 7),
        Instruction('???', nop, imp, 4),
        Instruction('CMP', cmp, abx, 4),
        Instruction('DEC', dec, abx, 7),
        Instruction('???', xxx, imp, 7),
        Instruction('CPX', cpx, imm, 2),
        Instruction('SBC', sbc, izx, 6),
        Instruction('???', nop, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('CPX', cpx, zp0, 3),
        Instruction('SBC', sbc, zp0, 3),
        Instruction('INC', inc, zp0, 5),
        Instruction('???', xxx, imp, 5),
        Instruction('INX', inx, imp, 2),
        Instruction('SBC', sbc, imm, 2),
        Instruction('NOP', nop, imp, 2),
        Instruction('???', sbc, imp, 2),
        Instruction('CPX', cpx, abs, 4),
        Instruction('SBC', sbc, abs, 4),
        Instruction('INC', inc, abs, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('BEQ', beq, rel, 2),
        Instruction('SBC', sbc, izy, 5),
        Instruction('???', xxx, imp, 2),
        Instruction('???', xxx, imp, 8),
        Instruction('???', nop, imp, 4),
        Instruction('SBC', sbc, zpx, 4),
        Instruction('INC', inc, zpx, 6),
        Instruction('???', xxx, imp, 6),
        Instruction('SED', sed, imp, 2),
        Instruction('SBC', sbc, aby, 4),
        Instruction('NOP', nop, imp, 2),
        Instruction('???', xxx, imp, 7),
        Instruction('???', nop, imp, 4),
        Instruction('SBC', sbc, abx, 4),
        Instruction('INC', inc, abx, 7),
        Instruction('???', xxx, imp, 7),
      ];
}
