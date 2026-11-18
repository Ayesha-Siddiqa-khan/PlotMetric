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
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 0;

    // Check decimal format
    final regex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!regex.hasMatch(trimmed)) return null;

    final parts = trimmed.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;

    int fraction = 0;
    if (parts.length > 1) {
      final fracStr = parts[1].padRight(2, '0');
      fraction = int.tryParse(fracStr) ?? 0;
    }

    final totalCenti = whole * 100 + fraction;
    if (totalCenti < 0 || totalCenti > 899) return null;

    return totalCenti;
  }
}
