class Instruction {
  Instruction(this.name, this.operate, this.addressMode, this.cycles);

  final String name;
  final int Function() operate;
  final int Function() addressMode;
  final int cycles;
}
