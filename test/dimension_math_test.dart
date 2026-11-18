import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/features/dimensions/logic/dimension_math.dart';

void main() {
  group('DimensionMath tests', () {
    test('User blueprint example: 10 ft 5 in width by 70 ft length', () {
      final result = DimensionMath.calculatePlotArea(
        widthFeet: 10,
        widthInches: 5,
        lengthFeet: 70,
        lengthInches: 0,
      );

      // Width: 10 * 12 + 5 = 125 inches
      expect(result.widthInches, 125.0);
      // Length: 70 * 12 = 840 inches
      expect(result.lengthInches, 840.0);
      // Total sq in: 125 * 840 = 105,000 sq in
      expect(result.totalSquareInches, 105000.0);

      // Square Feet: 105000 / 144 = 729.16666...
      expect(result.squareFeet, closeTo(729.17, 0.01));
      expect(result.squareFeetFormatted, '729.17');

      // Square yards: 729.17 / 9 = 81.02
      expect(result.squareYards, closeTo(81.02, 0.01));

      // Land breakdown: 2 Marla 6.1 Sarsai
      expect(result.compositeArea.kanal, 0);
      expect(result.compositeArea.marla, 2);
      expect(result.compositeArea.sarsaiCenti, 610);
      expect(result.compositeArea.toDisplayString(), '0 Kanal 2 Marla 6.1 Sarsai');
    });

    test('Standard land units direct square feet conversion', () {
      // 1 Kanal = 5,445 sq ft
      final kanalResult = DimensionMath.fromSquareFeet(5445.0);
      expect(kanalResult.compositeArea.kanal, 1);
      expect(kanalResult.compositeArea.marla, 0);
      expect(kanalResult.compositeArea.sarsaiCenti, 0);
      expect(kanalResult.compositeArea.toDisplayString(), '1 Kanal 0 Marla 0 Sarsai');

      // 1 Marla = 272.25 sq ft
      final marlaResult = DimensionMath.fromSquareFeet(272.25);
      expect(marlaResult.compositeArea.kanal, 0);
      expect(marlaResult.compositeArea.marla, 1);
      expect(marlaResult.compositeArea.sarsaiCenti, 0);
      expect(marlaResult.compositeArea.toDisplayString(), '0 Kanal 1 Marla 0 Sarsai');

      // 1 Sarsai = 30.25 sq ft
      final sarsaiResult = DimensionMath.fromSquareFeet(30.25);
      expect(sarsaiResult.compositeArea.kanal, 0);
      expect(sarsaiResult.compositeArea.marla, 0);
      expect(sarsaiResult.compositeArea.sarsaiCenti, 100);
      expect(sarsaiResult.compositeArea.toDisplayString(), '0 Kanal 0 Marla 1 Sarsai');
    });

    test('Custom square feet conversion: 1000 sq ft', () {
      final res = DimensionMath.fromSquareFeet(1000.0);
      // 1000 / 272.25 = 3.673 Marla = 3 Marla 6.06 Sarsai
      expect(res.compositeArea.kanal, 0);
      expect(res.compositeArea.marla, 3);
      expect(res.compositeArea.sarsaiCenti, closeTo(606, 2));
    });
  });
}
