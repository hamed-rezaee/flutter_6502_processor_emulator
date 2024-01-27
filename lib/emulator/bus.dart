import 'package:flutter_6502_processor_emulator/emulator/ram.dart';

class Bus {
  Bus(this.ram);

  final Ram ram;

  int read(int address) {
    if (address >= 0x0000 && address < ram.size) {
      return ram.data[address];
    }

    return 0x00;
  }

  void write(int address, int data) {
    if (address >= 0x0000 && address < ram.size) {
      ram.data[address] = data;
    }
  }
}
