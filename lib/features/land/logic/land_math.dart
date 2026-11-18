import '../../../core/constants/land_units.dart';
import '../../../core/utils/number_formatters.dart';

class LandCompositeArea {
  final bool isNegative;
  final int kanal;
  final int marla;
  final int sarsaiCenti;

  const LandCompositeArea({
    required this.isNegative,
    required this.kanal,
    required this.marla,
    required this.sarsaiCenti,
  });

  String get sarsaiFormatted => NumberFormatters.formatSarsaiFromCenti(sarsaiCenti);

  /// Formatted as "479 Kanal 14 Marla 7 Sarsai" or "- (1 Kanal 2 Marla 3 Sarsai)"
  String toDisplayString() {
    final sarsaiStr = sarsaiFormatted;
    final body = '$kanal Kanal $marla Marla $sarsaiStr Sarsai';
    return isNegative ? '- ($body)' : body;
  }
}

class LandWorksheetSummary {
  final int totalAddedUnits;
  final int totalDeductedUnits;
  final int netUnits;

  final int totalAddedSqFtTenThousandths;
  final int totalDeductedSqFtTenThousandths;
  final int netSqFtTenThousandths;

  final LandCompositeArea netCompositeArea;
  final LandCompositeArea grossCompositeArea;
  final LandCompositeArea totalDeductedCompositeArea;

  const LandWorksheetSummary({
    required this.totalAddedUnits,
    required this.totalDeductedUnits,
    required this.netUnits,
    required this.totalAddedSqFtTenThousandths,
    required this.totalDeductedSqFtTenThousandths,
    required this.netSqFtTenThousandths,
    required this.netCompositeArea,
    required this.grossCompositeArea,
    required this.totalDeductedCompositeArea,
  });

  bool get isNegative => netUnits < 0;

  double get deductionPercentage =>
      totalAddedUnits > 0 ? (totalDeductedUnits / totalAddedUnits) * 100.0 : 0.0;

  double get remainingPercentage =>
      totalAddedUnits > 0 ? (netUnits / totalAddedUnits) * 100.0 : 0.0;

  String get totalAddedSqFtFormatted =>
      NumberFormatters.formatSquareFeetFromTenThousandths(totalAddedSqFtTenThousandths);

  String get totalDeductedSqFtFormatted =>
      NumberFormatters.formatSquareFeetFromTenThousandths(totalDeductedSqFtTenThousandths);

  String get netSqFtFormatted =>
      NumberFormatters.formatSquareFeetFromTenThousandths(netSqFtTenThousandths);
}

class LandMath {
  const LandMath._();

  /// Converts kanal, marla, and sarsaiCenti into total integer centi-Sarsai
  static int rowToCentiSarsai({
    required int kanal,
    required int marla,
    required int sarsaiCenti,
  }) {
    return kanal * LandUnits.centiSarsaisPerKanal +
        marla * LandUnits.centiSarsaisPerMarla +
        sarsaiCenti;
  }

  /// Calculates square feet in units of 1/10,000 sq ft for a single row
  static int rowUnitsToSqFtTenThousandths(int centiSarsaiUnits, {bool isSubtract = false}) {
    final signed = isSubtract ? -centiSarsaiUnits : centiSarsaiUnits;
    return signed * LandUnits.tenThousandthsSqFtPerCentiSarsai;
  }

  /// Converts signed centi-Sarsai to composite Kanal, Marla, Sarsai
  static LandCompositeArea centiSarsaiToComposite(int netCentiSarsai) {
    final isNegative = netCentiSarsai < 0;
    final absUnits = netCentiSarsai.abs();

    final kanal = absUnits ~/ LandUnits.centiSarsaisPerKanal;
    final remAfterKanal = absUnits % LandUnits.centiSarsaisPerKanal;

    final marla = remAfterKanal ~/ LandUnits.centiSarsaisPerMarla;
    final sarsaiCenti = remAfterKanal % LandUnits.centiSarsaisPerMarla;

    return LandCompositeArea(
      isNegative: isNegative,
      kanal: kanal,
      marla: marla,
      sarsaiCenti: sarsaiCenti,
    );
  }

  /// Computes summary of additions, deductions, net area, and square feet
  static LandWorksheetSummary computeSummary(List<({bool isSubtract, int centiSarsai})> rows) {
    int addedUnits = 0;
    int deductedUnits = 0;

    for (final row in rows) {
      if (row.isSubtract) {
        deductedUnits += row.centiSarsai;
      } else {
        addedUnits += row.centiSarsai;
      }
    }

    final netUnits = addedUnits - deductedUnits;
    final addedSqFt = addedUnits * LandUnits.tenThousandthsSqFtPerCentiSarsai;
    final deductedSqFt = deductedUnits * LandUnits.tenThousandthsSqFtPerCentiSarsai;
    final netSqFt = netUnits * LandUnits.tenThousandthsSqFtPerCentiSarsai;

    return LandWorksheetSummary(
      totalAddedUnits: addedUnits,
      totalDeductedUnits: deductedUnits,
      netUnits: netUnits,
      totalAddedSqFtTenThousandths: addedSqFt,
      totalDeductedSqFtTenThousandths: deductedSqFt,
      netSqFtTenThousandths: netSqFt,
      netCompositeArea: centiSarsaiToComposite(netUnits),
      grossCompositeArea: centiSarsaiToComposite(addedUnits),
      totalDeductedCompositeArea: centiSarsaiToComposite(deductedUnits),
    );
  }

  /// Computes running remaining balances at each row index
  static List<int> computeRunningBalances(List<({bool isSubtract, int centiSarsai})> rows) {
    final balances = <int>[];
    int current = 0;
    for (final row in rows) {
      if (row.isSubtract) {
        current -= row.centiSarsai;
      } else {
        current += row.centiSarsai;
      }
      balances.add(current);
    }
    return balances;
  }
}
