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
  late String inputKanal = kanal == 0 ? '' : '$kanal';
  late String inputMarla = marla == 0 ? '' : '$marla';
  late String inputSarsai = sarsaiCenti == 0 ? '' : NumberFormatters.formatSarsaiFromCenti(sarsaiCenti);
  bool invalidInput = false;

  ParsedMeasurementItem({
    required this.operation,
    required this.purpose,
    required this.kanal,
    required this.marla,
    required this.sarsaiCenti,
    this.sourceSquareFeet,
  });

  bool get isSubtract => operation == EntryOperation.subtract;

  void updateArea(int column, String text) {
    switch (column) {
      case 0: inputKanal = text;
      case 1: inputMarla = text;
      case 2: inputSarsai = text;
    }
    final units = LandMath.parseAreaInput(inputKanal, inputMarla, inputSarsai);
    invalidInput = units == null;
    if (units == null) return;
    final area = LandMath.centiSarsaiToComposite(units);
    kanal = area.kanal;
    marla = area.marla;
    sarsaiCenti = area.sarsaiCenti;
  }

  int get centiSarsai => LandMath.rowToCentiSarsai(
        kanal: kanal,
        marla: marla,
        sarsaiCenti: sarsaiCenti,
      );

  String get sqFtFormatted => NumberFormatters.formatSquareFeetFromTenThousandths(
        LandMath.rowUnitsToSqFtTenThousandths(centiSarsai),
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

    final hasLabeledUnits = RegExp(
      r'\d\s*(?:kanals?|marlas?|sarsai|sarsaye|[kms])\b|\d\s*(?:کنال|مرلہ|سرسائی)',
      caseSensitive: false,
    ).hasMatch(line.replaceAll(_squareFeet, ''));
    if (squareFeet != null && compact == null && !hasLabeledUnits) {
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

    var k = '', m = '', s = '';
    if (compact != null) {
      for (final match in _compactUnits.allMatches(line)) {
        final amount = '${match.group(2)}${match.group(3) ?? ''}';
        switch (match.group(1)!.toLowerCase()) {
          case 'k':
            k = amount;
          case 'm':
            m = amount;
          case 's':
            final fraction = match.group(4);
            if (fraction == null) {
              s = amount;
            } else {
              final whole = int.tryParse(amount);
              final numerator = int.tryParse(fraction);
              final denominator = int.tryParse(match.group(5)!);
              if (whole == null || whole > 8 || numerator == null || numerator > 99 ||
                  denominator == null || denominator == 0 || numerator >= denominator) {
                return null;
              }
              s = NumberFormatters.formatSarsaiFromCenti(whole * 100 +
                  (100 * numerator + denominator ~/ 2) ~/ denominator);
            }
        }
      }
    } else {
      const number = r'(?<![\d.])(\d+(?:\.\d{1,2})?)';
      String labeled(String units) => RegExp(
        '$number\\s*(?:$units)' r'(?:\b|\s|$|[:\-,])',
        caseSensitive: false,
      ).firstMatch(line)?.group(1) ?? '';
      k = labeled('kanals?|k|کنال');
      m = labeled('marlas?|m|مرلہ');
      s = labeled('sarsai|sarsaye|s|سرسائی');
      if (k.isEmpty && m.isEmpty && s.isEmpty) {
        if (RegExp(r'\d+(?:\.\d+)?').allMatches(line).length > 3) return null;
        final values = RegExp(r'(?<![\d.])(\d+(?:\.\d{1,2})?)[-\s/]+(\d+(?:\.\d{1,2})?)(?:[-\s/]+(\d+(?:\.\d{1,2})?))?(?![\d.])').firstMatch(line);
        if (values == null) return null;
        k = values.group(1)!;
        m = values.group(2)!;
        s = values.group(3) ?? '';
      }
    }
    final units = LandMath.parseAreaInput(k, m, s, allowCarry: true);
    if (units == null) return null;
    final area = LandMath.centiSarsaiToComposite(units);
    return ParsedMeasurementItem(
      operation: operation,
      purpose: purpose,
      kanal: area.kanal,
      marla: area.marla,
      sarsaiCenti: area.sarsaiCenti,
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
