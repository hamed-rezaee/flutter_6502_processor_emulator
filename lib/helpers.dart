String formatHex(int value, {int precision = 4, String prefix = r'$'}) =>
    '$prefix${value.toRadixString(16).toUpperCase().padLeft(precision, '0')}';
