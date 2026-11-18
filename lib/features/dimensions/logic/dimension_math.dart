import '../../../core/constants/land_units.dart';
import '../../../core/utils/number_formatters.dart';
import '../../land/logic/land_math.dart';

class DimensionCalculationResult {
  final double lengthInches;
  final double widthInches;
  final double totalSquareInches;
  final double squareFeet;
  final double squareYards; // 1 sq yard = 9 sq ft
  final int centiSarsai;
  final LandCompositeArea compositeArea;

  const DimensionCalculationResult({
    required this.lengthInches,
    required this.widthInches,
    required this.totalSquareInches,
    required this.squareFeet,
    required this.squareYards,
    required this.centiSarsai,
    required this.compositeArea,
  });

  String get squareFeetFormatted => squareFeet.toStringAsFixed(2);

  String get squareYardsFormatted => squareYards.toStringAsFixed(2);
}

class DimensionMath {
  const DimensionMath._();

  /// Converts feet and inches into total decimal inches
  static double toInches({required int feet, required double inches}) {
    return (feet * 12.0) + inches;
  }

  /// Calculates plot area from length (feet + inches) and width (feet + inches)
  static DimensionCalculationResult calculatePlotArea({
    required int lengthFeet,
    required double lengthInches,
    required int widthFeet,
    required double widthInches,
  }) {
    final totalLengthInches = toInches(feet: lengthFeet, inches: lengthInches);
    final totalWidthInches = toInches(feet: widthFeet, inches: widthInches);

    final totalSqInches = totalLengthInches * totalWidthInches;
    final sqFeet = totalSqInches / 144.0;
    final sqYards = sqFeet / 9.0;

    // Convert sq ft to centi-Sarsai (1 centi-Sarsai = 0.3025 sq ft)
    // tenThousandthsSqFt = sqFeet * 10000
    // centiSarsai = tenThousandthsSqFt / 3025
    final tenThousandthsSqFt = (sqFeet * 10000.0).round();
    final centiSarsai = (tenThousandthsSqFt / LandUnits.tenThousandthsSqFtPerCentiSarsai).round();

    final composite = LandMath.centiSarsaiToComposite(centiSarsai);

    return DimensionCalculationResult(
      lengthInches: totalLengthInches,
      widthInches: totalWidthInches,
      totalSquareInches: totalSqInches,
      squareFeet: sqFeet,
      squareYards: sqYards,
      centiSarsai: centiSarsai,
      compositeArea: composite,
    );
  }

  /// Converts direct square feet to Kanal, Marla, Sarsai
  static DimensionCalculationResult fromSquareFeet(double sqFeet) {
    final sqYards = sqFeet / 9.0;
    final totalSqInches = sqFeet * 144.0;

    final tenThousandthsSqFt = (sqFeet * 10000.0).round();
    final centiSarsai = (tenThousandthsSqFt / LandUnits.tenThousandthsSqFtPerCentiSarsai).round();
    final composite = LandMath.centiSarsaiToComposite(centiSarsai);

    return DimensionCalculationResult(
      lengthInches: 0,
      widthInches: 0,
      totalSquareInches: totalSqInches,
      squareFeet: sqFeet,
      squareYards: sqYards,
      centiSarsai: centiSarsai,
      compositeArea: composite,
    );
  }
}
