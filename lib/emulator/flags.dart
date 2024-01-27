class Flags {
  bool c = false;
  bool z = false;
  bool i = false;
  bool d = false;
  bool b = false;
  bool u = false;
  bool v = false;
  bool n = false;

  int get status =>
      (c ? 0x01 : 0x00) |
      (z ? 0x02 : 0x00) |
      (i ? 0x04 : 0x00) |
      (d ? 0x08 : 0x00) |
      (b ? 0x10 : 0x00) |
      (u ? 0x20 : 0x00) |
      (v ? 0x40 : 0x00) |
      (n ? 0x80 : 0x00);

  set status(int value) {
    c = (value & 0x01) != 0;
    z = (value & 0x02) != 0;
    i = (value & 0x04) != 0;
    d = (value & 0x08) != 0;
    b = (value & 0x10) != 0;
    u = (value & 0x20) != 0;
    v = (value & 0x40) != 0;
    n = (value & 0x80) != 0;
  }
}
