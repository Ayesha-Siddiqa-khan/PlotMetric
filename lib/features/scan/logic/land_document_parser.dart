import '../../../core/constants/land_units.dart';
import '../../../core/utils/number_formatters.dart';
import '../../../data/models/measurement_entry.dart';
import '../../land/logic/land_math.dart';

class ParsedMeasurementItem {
  EntryOperation operation;
  String purpose;
  int kanal;
  int marla;
  int sarsaiCenti;
  final String? sourceSquareFeet;

  ParsedMeasurementItem({
    required this.operation,
    required this.purpose,
    required this.kanal,
    required this.marla,
    required this.sarsaiCenti,
    this.sourceSquareFeet,
  });

  bool get isSubtract => operation == EntryOperation.subtract;

  int get centiSarsai => LandMath.rowToCentiSarsai(
        kanal: kanal,
        marla: marla,
        sarsaiCenti: sarsaiCenti,
      );

  String get sqFtFormatted => NumberFormatters.formatSquareFeetFromTenThousandths(
        LandMath.rowUnitsToSqFtTenThousandths(centiSarsai, isSubtract: isSubtract),
      );
}

class LandDocumentParser {
  const LandDocumentParser._();

  static const List<String> deductionKeywords = [
    'deduct',
    'deduction',
    'road',
    'roads',
    'minus',
    'sub',
    'cut',
    'sewerage',
    'drain',
    'coverd area',
    'covered area',
    'shade area',
    'shaded area',
    'کٹوتی',
    'منہائی',
    'سڑک',
    'راستہ',
  ];

  static const List<String> purposeKeywords = [
    'total area of plot',
    'total land',
    'coverd area',
    'covered area',
    'shade area',
    'shaded area',
    'plot area',
    'floor plan',
    'total area',
    'gross area',
    'roads',
    'sewerage',
    'mosque',
    'dispensary',
    'graveyard',
    'parks',
    'park',
    'school',
    'community centre',
    'water supply',
    'utilities',
    'commercial',
    'residential',
    'open space',
    'green belt',
    'grid station',
    'overhead tank',
    'masjid',
    'کل رقبہ',
    'سڑکیں',
    'مسجد',
    'پارک',
    'قبرستان',
    'سیوریج',
  ];

  /// Parses text from OCR or pasted document into structured measurement items
  static List<ParsedMeasurementItem> parseDocumentText(String rawText) {
    final results = <ParsedMeasurementItem>[];
    final lines = rawText.split(RegExp(r'[\r\n]+'));

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final parsedItem = _parseLine(line);
      if (parsedItem != null) {
        results.add(parsedItem);
      }
    }

    return results;
  }

  static ParsedMeasurementItem? _parseLine(String line) {
    final lower = line.toLowerCase();

    // 1. Determine Purpose
    String purpose = 'Nil';
    for (final kw in purposeKeywords) {
      if (lower.contains(kw)) {
        // Capitalize properly
        purpose = _formatPurpose(kw);
        break;
      }
    }

    // If purpose not found in keywords, check before a colon or dash
    if (purpose == 'Nil') {
      final colonSplit = line.split(RegExp(r'[:\-]'));
      if (colonSplit.length > 1 && colonSplit.first.trim().length <= 40) {
        final candidate = colonSplit.first.trim();
        // Ensure it doesn't start with numbers
        if (!RegExp(r'^\d').hasMatch(candidate)) {
          purpose = candidate;
        }
      }
    }

    // 2. Determine Operation (Add vs Deduct)
    EntryOperation operation = EntryOperation.add;
    final compact = _compactUnits.firstMatch(line);
    final squareFeet = _squareFeet.firstMatch(line);
    final isExplicitDeduct = deductionKeywords.any(lower.contains) ||
        (compact == null && squareFeet == null && line.contains('-')) ||
        RegExp(r'^\s*-').hasMatch(line);
    if (isExplicitDeduct && !lower.contains('total area') &&
        !lower.contains('total land') && !lower.contains('gross')) {
      operation = EntryOperation.subtract;
    }

    // 3. Extract Kanal, Marla, Sarsai
    int kanal = 0;
    int marla = 0;
    int sarsaiCenti = 0;

    if (squareFeet != null) {
      const unit = LandUnits.tenThousandthsSqFtPerCentiSarsai;
      const maxSquareFeet = (LandUnits.maxKanal + 1) * LandUnits.centiSarsaisPerKanal * unit ~/ 10000;
      final whole = int.tryParse(squareFeet.group(1)!.replaceAll(',', ''));
      if (whole == null || whole > maxSquareFeet) return null;
      final decimals = (squareFeet.group(2) ?? '').padRight(4, '0');
      final scaled = whole * 10000 + int.parse(decimals);
      final area = LandMath.centiSarsaiToComposite((scaled + unit ~/ 2) ~/ unit);
      if (area.kanal > LandUnits.maxKanal) return null;
      return ParsedMeasurementItem(
        operation: operation,
        purpose: purpose,
        kanal: area.kanal,
        marla: area.marla,
        sarsaiCenti: area.sarsaiCenti,
        sourceSquareFeet: squareFeet.group(2) == null ? '$whole' : '$whole.${squareFeet.group(2)}',
      );
    }

    if (compact != null) {
      for (final match in _compactUnits.allMatches(line)) {
        final amount = int.tryParse(match.group(2)!);
        if (amount == null) return null;
        switch (match.group(1)!.toLowerCase()) {
          case 'k':
            kanal = amount;
          case 'm':
            marla = amount;
          case 's':
            final fraction = match.group(4);
            if (fraction == null) {
              sarsaiCenti = NumberFormatters.parseSarsaiToCenti(
                '$amount${match.group(3) ?? ''}',
              ) ?? 0;
            } else {
              final numerator = int.tryParse(fraction);
              final denominator = int.tryParse(match.group(5)!);
              if (amount > 8 || numerator == null || numerator > 99 ||
                  denominator == null || denominator == 0 || numerator >= denominator) {
                return null;
              }
              sarsaiCenti = amount * 100 + (100 * numerator + denominator ~/ 2) ~/ denominator;
            }
        }
      }
      if (kanal > LandUnits.maxKanal || marla > LandUnits.maxMarla ||
          sarsaiCenti > LandUnits.maxSarsaiCenti) {
        return null;
      }
      return ParsedMeasurementItem(
        operation: operation,
        purpose: purpose,
        kanal: kanal,
        marla: marla,
        sarsaiCenti: sarsaiCenti,
      );
    }

    // Pattern A: "X Kanal Y Marla Z Sarsai" or "X K Y M Z S" or Urdu "X کنال Y مرلہ Z سرسائی"
    final kanalMatch = RegExp(r'(\d+)\s*(?:kanal|kanals|k|کنال)(?:\b|\s|$|[:\-,])', caseSensitive: false)
        .firstMatch(line);
    if (kanalMatch != null) {
      kanal = int.tryParse(kanalMatch.group(1)!) ?? 0;
    }

    final marlaMatch = RegExp(r'(\d+)\s*(?:marla|marlas|m|مرلہ)(?:\b|\s|$|[:\-,])', caseSensitive: false)
        .firstMatch(line);
    if (marlaMatch != null) {
      marla = int.tryParse(marlaMatch.group(1)!) ?? 0;
    }

    final sarsaiMatch = RegExp(
      r'(\d+(?:\.\d{1,2})?)\s*(?:sarsai|sarsaye|s|سرسائی)(?:\b|\s|$|[:\-,])',
      caseSensitive: false,
    ).firstMatch(line);
    if (sarsaiMatch != null) {
      sarsaiCenti = NumberFormatters.parseSarsaiToCenti(sarsaiMatch.group(1)!) ?? 0;
    }

    // Pattern B: Delimited numbers like "20-5-2" or "20 5 2" or "500-0-0"
    if (kanal == 0 && marla == 0 && sarsaiCenti == 0) {
      final numbersMatch = RegExp(r'(\d+)[-\s/]+(\d+)(?:[-\s/]+(\d+(?:\.\d{1,2})?))?')
          .firstMatch(line);
      if (numbersMatch != null) {
        kanal = int.tryParse(numbersMatch.group(1)!) ?? 0;
        marla = int.tryParse(numbersMatch.group(2)!) ?? 0;
        if (numbersMatch.group(3) != null) {
          sarsaiCenti =
              NumberFormatters.parseSarsaiToCenti(numbersMatch.group(3)!) ?? 0;
        }
      }
    }

    // Pattern C: Single number with Kanal or Marla (e.g. "500 Kanal")
    if (kanal == 0 && marla == 0 && sarsaiCenti == 0) {
      final singleKanal = RegExp(r'\b(\d+)\s*(?:kanal|kanals|k)\b', caseSensitive: false)
          .firstMatch(line);
      if (singleKanal != null) {
        kanal = int.tryParse(singleKanal.group(1)!) ?? 0;
      }
    }

    // Clamp / bounds check
    if (kanal > LandUnits.maxKanal) kanal = LandUnits.maxKanal;
    if (marla > LandUnits.maxMarla) marla = LandUnits.maxMarla;
    if (sarsaiCenti > LandUnits.maxSarsaiCenti) sarsaiCenti = LandUnits.maxSarsaiCenti;

    if (kanalMatch == null && marlaMatch == null && sarsaiMatch == null &&
        kanal == 0 && marla == 0 && sarsaiCenti == 0) {
      return null; // Not a measurement line
    }

    return ParsedMeasurementItem(
      operation: operation,
      purpose: purpose,
      kanal: kanal,
      marla: marla,
      sarsaiCenti: sarsaiCenti,
    );
  }

  static final _squareFeet = RegExp(
    r'(?<![\d.,])\b(\d+(?:,\d{3})*)(?:\.(\d{1,4}))?\s*(?:s\s*f\s*t|sq\.?\s*(?:ft|feet)|ft[²2]|square feet)\b',
    caseSensitive: false,
  );

  static final _compactUnits = RegExp(
    r'\b([kms])\s*[-–:]\s*(\d+)(\.\d{1,2})?(?:\s*[-–]\s*(\d+)\s*/\s*(\d+))?\b',
    caseSensitive: false,
  );

  static String _formatPurpose(String kw) {
    switch (kw.toLowerCase()) {
      case 'total area':
      case 'gross area':
      case 'total area of plot':
      case 'plot area':
      case 'کل رقبہ':
        return 'Total Area';
      case 'total land':
        return 'Total Land';
      case 'coverd area':
      case 'covered area':
        return 'Covered Area';
      case 'shade area':
      case 'shaded area':
        return 'Shade Area';
      case 'roads':
      case 'road':
      case 'سڑکیں':
        return 'Roads';
      case 'sewerage':
      case 'سیوریج':
        return 'Sewerage';
      case 'mosque':
      case 'masjid':
      case 'مسجد':
        return 'Mosque';
      case 'dispensary':
        return 'Dispensary';
      case 'graveyard':
      case 'قبرستان':
        return 'Graveyard';
      case 'parks':
      case 'park':
      case 'پارک':
        return 'Parks';
      case 'school':
        return 'School';
      case 'community centre':
        return 'Community Centre';
      case 'water supply':
        return 'Water Supply';
      case 'utilities':
        return 'Utilities';
      case 'commercial':
        return 'Commercial';
      case 'residential':
        return 'Residential';
      default:
        return kw[0].toUpperCase() + kw.substring(1);
    }
  }
}
