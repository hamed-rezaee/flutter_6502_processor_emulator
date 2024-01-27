import 'package:flutter_6502_processor_emulator/emulator/cpu.dart';
import 'package:flutter_6502_processor_emulator/emulator/instruction.dart';
import 'package:flutter_6502_processor_emulator/extensions.dart';

Map<int, String> disassemble(Cpu cpu, int start, int stop) {
  final Map<int, String> result = <int, String>{};

  final List<Instruction> lookup = cpu.lookup;

  int address = start;
  int value = 0x00;
  int low = 0x00;
  int high = 0x00;
  int lineAddress = 0;

  while (address <= stop) {
    lineAddress = address;

    final int opCode = cpu.read(address);
    final int Function() addressMode = lookup[opCode].addressMode;

    String instruction = '${address.printHex()}: ';
    address++;
    instruction += '${lookup[opCode].name} ';

    if (addressMode == cpu.imp) {
      instruction += '      {IMP}';
    } else if (addressMode == cpu.imm) {
      value = cpu.read(address);
      address++;
      instruction += '#${value.printHex(precision: 2)}  {IMM}';
    } else if (addressMode == cpu.zp0) {
      low = cpu.read(address);
      address++;
      high = 0x00;
      instruction += '${low.printHex(precision: 2)}   {ZP0}';
    } else if (addressMode == cpu.zpx) {
      low = cpu.read(address);
      address++;
      high = 0x00;
      instruction += '${low.printHex(precision: 2)}, X {ZPX}';
    } else if (addressMode == cpu.zpy) {
      low = cpu.read(address);
      address++;
      high = 0x00;
      instruction += '${low.printHex(precision: 2)}, Y {ZPY}';
    } else if (addressMode == cpu.izx) {
      low = cpu.read(address);
      address++;
      high = 0x00;
      instruction += '(${low.printHex(precision: 2)}, X) {IZX}';
    } else if (addressMode == cpu.izy) {
      low = cpu.read(address);
      address++;
      high = 0x00;
      instruction += '(${low.printHex(precision: 2)}, Y) {IZY}';
    } else if (addressMode == cpu.abs) {
      low = cpu.read(address);
      address++;
      high = cpu.read(address);
      address++;
      instruction += '${(high << 8 | low).printHex()} {ABS}';
    } else if (addressMode == cpu.abx) {
      low = cpu.read(address);
      address++;
      high = cpu.read(address);
      address++;
      instruction += '${(high << 8 | low).printHex()}, X {ABX}';
    } else if (addressMode == cpu.aby) {
      low = cpu.read(address);
      address++;
      high = cpu.read(address);
      address++;
      instruction += '${(high << 8 | low).printHex()}, Y {ABY}';
    } else if (addressMode == cpu.ind) {
      low = cpu.read(address);
      address++;
      high = cpu.read(address);
      address++;
      instruction += '(${(high << 8 | low).printHex()}) {IND}';
    } else if (addressMode == cpu.rel) {
      value = cpu.read(address);
      address++;
      instruction +=
          '${value.printHex(precision: 2)} [${(address + value).printHex()}] {REL}';
    }

    result[lineAddress] = instruction;
  }

  return result;
}
