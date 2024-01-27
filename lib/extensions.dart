import 'package:flutter_6502_processor_emulator/helpers.dart';

extension IntExtensions on int {
  String printHex({int precision = 4, String prefix = r'$'}) =>
      formatHex(this, precision: precision, prefix: prefix);
}
