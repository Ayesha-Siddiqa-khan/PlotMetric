import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/features/calculator/logic/expression_evaluator.dart';

void main() {
  group('ExpressionEvaluator tests', () {
    test('PRD requirement: 12 + 8 × 3 = 36', () {
      final result = ExpressionEvaluator.evaluate(['12', '+', '8', '×', '3']);
      expect(result.isSuccess, true);
      expect(result.value, 36.0);
    });

    test('PRD requirement: 7.5 × 4 = 30', () {
      final result = ExpressionEvaluator.evaluate(['7.5', '×', '4']);
      expect(result.isSuccess, true);
      expect(result.value, 30.0);
    });

    test('PRD requirement: division by zero produces safe error', () {
      final result = ExpressionEvaluator.evaluate(['10', '÷', '0']);
      expect(result.isSuccess, false);
      expect(result.error, contains('divide by zero'));
    });

    test('Mixed operations with precedence: 100 - 20 ÷ 4 + 3 × 2 = 101', () {
      final result = ExpressionEvaluator.evaluate([
        '100',
        '-',
        '20',
        '÷',
        '4',
        '+',
        '3',
        '×',
        '2',
      ]);
      expect(result.isSuccess, true);
      expect(result.value, 101.0);
    });

    test('Decimal and negative evaluations', () {
      final result = ExpressionEvaluator.evaluate(['-5', '+', '15']);
      expect(result.isSuccess, true);
      expect(result.value, 10.0);
    });

    test('Empty expression handled safely', () {
      final result = ExpressionEvaluator.evaluate([]);
      expect(result.isSuccess, false);
      expect(result.error, 'Empty expression');
    });
  });
}
