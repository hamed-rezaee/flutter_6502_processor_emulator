class Ram {
  Ram([this.size = 0xFFFF]) : data = List<int>.filled(size, 0x00);

  final int size;
  final List<int> data;
}
