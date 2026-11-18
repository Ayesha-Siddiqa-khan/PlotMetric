import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/core/constants/land_units.dart';
import 'package:plotmetric/core/utils/number_formatters.dart';
import 'package:plotmetric/features/land/logic/land_math.dart';

void main() {
  group('LandUnits constants verification', () {
    test('standard conversions match 272.25 sq ft per Marla profile', () {
      expect(LandUnits.marlasPerKanal, 20);
      expect(LandUnits.sarsaisPerMarla, 9);
      expect(LandUnits.sarsaisPerKanal, 180);
      expect(LandUnits.centiSarsaisPerKanal, 18000);
      expect(LandUnits.centiSarsaisPerMarla, 900);
      expect(LandUnits.centiSarsaisPerSarsai, 100);
    });
  });

  group('LandMath & NumberFormatters tests', () {
    test('PRD Section 4.3 Ittefaq City example with exact figures', () {
      // Line 1: + 500 Kanal, 0 Marla, 0 Sarsai
      final line1Centi = LandMath.rowToCentiSarsai(
        kanal: 500,
        marla: 0,
        sarsaiCenti: 0,
      );
      expect(line1Centi, 500 * 18000); // 9,000,000 centi-Sarsai

      final line1SqFtTenThousandths =
          LandMath.rowUnitsToSqFtTenThousandths(line1Centi, isSubtract: false);
      expect(
        NumberFormatters.formatSquareFeetFromTenThousandths(line1SqFtTenThousandths),
        '2,722,500.00',
      );

      // Line 2: − Roads: 20 Kanal, 5 Marla, 2 Sarsai
      final line2Centi = LandMath.rowToCentiSarsai(
        kanal: 20,
        marla: 5,
        sarsaiCenti: 200,
      );
      // 20 * 18000 + 5 * 900 + 200 = 360,000 + 4,500 + 200 = 364,700
      expect(line2Centi, 364700);

      final line2SqFtTenThousandths =
          LandMath.rowUnitsToSqFtTenThousandths(line2Centi, isSubtract: false);
      expect(
        NumberFormatters.formatSquareFeetFromTenThousandths(line2SqFtTenThousandths),
        '110,321.75',
      );

      // Summary
      final summary = LandMath.computeSummary([
        (isSubtract: false, centiSarsai: line1Centi),
        (isSubtract: true, centiSarsai: line2Centi),
      ]);

      expect(summary.totalAddedSqFtFormatted, '2,722,500.00');
      expect(summary.totalDeductedSqFtFormatted, '110,321.75');
      expect(summary.netSqFtFormatted, '2,612,178.25');

      final composite = summary.netCompositeArea;
      expect(composite.isNegative, false);
      expect(composite.kanal, 479);
      expect(composite.marla, 14);
      expect(composite.sarsaiCenti, 700);
      expect(composite.toDisplayString(), '479 Kanal 14 Marla 7 Sarsai');
    });

    test('0.01 Sarsai renders 0.3025 sq ft without rounding precision away', () {
      final centi = LandMath.rowToCentiSarsai(kanal: 0, marla: 0, sarsaiCenti: 1);
      final sqFt = LandMath.rowUnitsToSqFtTenThousandths(centi, isSubtract: false);
      expect(NumberFormatters.formatSquareFeetFromTenThousandths(sqFt), '0.3025');
    });

    test('1 Marla renders 272.25 sq ft', () {
      final centi = LandMath.rowToCentiSarsai(kanal: 0, marla: 1, sarsaiCenti: 0);
      final sqFt = LandMath.rowUnitsToSqFtTenThousandths(centi, isSubtract: false);
      expect(NumberFormatters.formatSquareFeetFromTenThousandths(sqFt), '272.25');
    });

    test('19 Marla 8 Sarsai + 1 Sarsai normalizes to 1 Kanal 0 Marla 0 Sarsai', () {
      final centi1 = LandMath.rowToCentiSarsai(kanal: 0, marla: 19, sarsaiCenti: 800);
      final centi2 = LandMath.rowToCentiSarsai(kanal: 0, marla: 0, sarsaiCenti: 100);

      final summary = LandMath.computeSummary([
        (isSubtract: false, centiSarsai: centi1),
        (isSubtract: false, centiSarsai: centi2),
      ]);

      expect(summary.netCompositeArea.kanal, 1);
      expect(summary.netCompositeArea.marla, 0);
      expect(summary.netCompositeArea.sarsaiCenti, 0);
      expect(summary.netCompositeArea.toDisplayString(), '1 Kanal 0 Marla 0 Sarsai');
      expect(summary.netSqFtFormatted, '5,445.00');
    });

    test('Negative net area is formatted with leading minus without clamping', () {
      final centi1 = LandMath.rowToCentiSarsai(kanal: 1, marla: 0, sarsaiCenti: 0);
      final centi2 = LandMath.rowToCentiSarsai(kanal: 2, marla: 5, sarsaiCenti: 300);

      final summary = LandMath.computeSummary([
        (isSubtract: false, centiSarsai: centi1),
        (isSubtract: true, centiSarsai: centi2),
      ]);

      expect(summary.isNegative, true);
      expect(summary.netCompositeArea.isNegative, true);
      expect(summary.netCompositeArea.kanal, 1);
      expect(summary.netCompositeArea.marla, 5);
      expect(summary.netCompositeArea.sarsaiCenti, 300);
      expect(summary.netCompositeArea.toDisplayString(), '- (1 Kanal 5 Marla 3 Sarsai)');
      expect(summary.netSqFtFormatted, '-6,897.00');
    });

    test('NumberFormatters parseSarsaiToCenti edge cases', () {
      expect(NumberFormatters.parseSarsaiToCenti(''), 0);
      expect(NumberFormatters.parseSarsaiToCenti('0'), 0);
      expect(NumberFormatters.parseSarsaiToCenti('2'), 200);
      expect(NumberFormatters.parseSarsaiToCenti('2.5'), 250);
      expect(NumberFormatters.parseSarsaiToCenti('8.99'), 899);
      expect(NumberFormatters.parseSarsaiToCenti('9.0'), null); // exceeds 8.99 limit
      expect(NumberFormatters.parseSarsaiToCenti('-1'), null);
      expect(NumberFormatters.parseSarsaiToCenti('abc'), null);
    });
  });
}
