import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/core/utils/date_time_formatters.dart';

void main() {
  group('DateTimeFormatters tests', () {
    test('Formats display date as dd/MM/yy', () {
      final date = DateTime(2026, 11, 18);
      expect(DateTimeFormatters.formatDisplayDate(date), '18/11/26');
    });

    test('Formats storage date as yyyy-MM-dd', () {
      final date = DateTime(2026, 11, 18);
      expect(DateTimeFormatters.formatStorageDate(date), '2026-11-18');
    });

    test('Validates real dates and rejects 31/02/26', () {
      final valid = DateTimeFormatters.parseDisplayDate('18/11/26');
      expect(valid, isNotNull);
      expect(valid!.year, 2026);
      expect(valid.month, 11);
      expect(valid.day, 18);

      final invalidFeb = DateTimeFormatters.parseDisplayDate('31/02/26');
      expect(invalidFeb, isNull);

      final invalidMonth = DateTimeFormatters.parseDisplayDate('10/13/26');
      expect(invalidMonth, isNull);
    });

    test('Converts between storage and display dates and times', () {
      expect(DateTimeFormatters.storageToDisplayDate('2026-11-18'), '18/11/26');
      expect(DateTimeFormatters.storageToDisplayTime('17:43'), '05:43 PM');
      expect(DateTimeFormatters.storageToDisplayTime('09:05'), '09:05 AM');
    });
  });
}
