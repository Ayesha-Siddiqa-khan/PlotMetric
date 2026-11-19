import 'package:intl/intl.dart';

class NumberFormatters {
  const NumberFormatters._();

  static final NumberFormat _integerGroupingFormat = NumberFormat('#,##0', 'en_US');

  /// Formats exact square feet given in units of 1/10,000th sq ft.
  /// Displays English commas, at least 2 decimal places, and up to 4 decimal
  /// places if necessary to preserve precision (e.g. 0.3025).
  static String formatSquareFeetFromTenThousandths(int tenThousandths, {bool includeUnit = false}) {
    final isNegative = tenThousandths < 0;
    final absVal = tenThousandths.abs();

    final whole = absVal ~/ 10000;
    final fraction = absVal % 10000;

    final wholeFormatted = _integerGroupingFormat.format(whole);

    String fractionStr;
    if (fraction % 100 == 0) {
      // 2 decimal places suffice (e.g. .25, .00)
      fractionStr = (fraction ~/ 100).toString().padLeft(2, '0');
    } else {
      // Needs up to 4 decimal places without trailing zeros beyond 2 places
      fractionStr = fraction.toString().padLeft(4, '0');
      // Trim unnecessary trailing zeros if any (e.g. .3020 -> .302), but keep at least 2
      while (fractionStr.length > 2 && fractionStr.endsWith('0')) {
        fractionStr = fractionStr.substring(0, fractionStr.length - 1);
      }
    }

    final sign = isNegative ? '-' : '';
    final result = '$sign$wholeFormatted.$fractionStr';
    return includeUnit ? '$result sq ft' : result;
  }

  /// Formats Sarsai value: displays up to 2 decimal places, trimming trailing .00 if needed.
  static String formatSarsaiFromCenti(int centiSarsai) {
    final whole = centiSarsai ~/ 100;
    final fraction = centiSarsai % 100;
    if (fraction == 0) {
      return whole.toString();
    }
    final fractionStr = fraction.toString().padLeft(2, '0');
    if (fractionStr.endsWith('0')) {
      return '$whole.${fractionStr[0]}';
    }
    return '$whole.$fractionStr';
  }

  /// Parse Sarsai text string to centi-Sarsai (0..899).
  /// Blank string returns 0.
  /// Invalid format or out-of-range returns null.
  static int? parseSarsaiToCenti(String input) {
    return parseFixedArea(input, 2, maximum: 899);
  }

  /// Parses decimal text directly into scaled integer units.
  static int? parseFixedArea(String text, int places, {required int maximum}) {
    final input = text.trim().replaceAllMapped(
      RegExp(r'[۰-۹٠-٩]'),
      (match) => (match[0]!.codeUnitAt(0) % 16).toString(),
    ).replaceAll('٫', '.').replaceAll('٬', ',');
    if (input.isEmpty) return 0;
    if (!RegExp(r'^(?:(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?|\.\d+)$').hasMatch(input)) return null;
    final parts = input.replaceAll(',', '').split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    final whole = int.tryParse(parts.first.isEmpty ? '0' : parts.first);
    if (whole == null || fraction.length > places) return null;
    var scale = 1;
    for (var i = 0; i < places; i++) {
      scale *= 10;
    }
    if (whole > maximum ~/ scale) return null;
    final value = whole * scale + (int.tryParse(fraction.padRight(places, '0')) ?? 0);
    return value <= maximum ? value : null;
  }
}
