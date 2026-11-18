import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/data/models/measurement_entry.dart';
import 'package:plotmetric/features/scan/logic/land_document_parser.dart';

void main() {
  group('LandDocumentParser tests', () {
    test('Parses standard English colony mutation text', () {
      const documentText = '''
        Ittefaq City Housing Scheme Plan
        Total Area: 500 Kanal, 0 Marla, 0 Sarsai
        Roads Deduction: 20 Kanal, 5 Marla, 2 Sarsai
        Sewerage: 3 Kanal 10 Marla
        Central Mosque: 1 Kanal
        Parks: 15 Kanal 8 Marla 4.5 Sarsai
      ''';

      final items = LandDocumentParser.parseDocumentText(documentText);
      expect(items.length, 5);

      // Line 1: Total Area
      expect(items[0].purpose, 'Total Area');
      expect(items[0].operation, EntryOperation.add);
      expect(items[0].kanal, 500);
      expect(items[0].marla, 0);
      expect(items[0].sarsaiCenti, 0);

      // Line 2: Roads
      expect(items[1].purpose, 'Roads');
      expect(items[1].operation, EntryOperation.subtract);
      expect(items[1].kanal, 20);
      expect(items[1].marla, 5);
      expect(items[1].sarsaiCenti, 200);

      // Line 3: Sewerage
      expect(items[2].purpose, 'Sewerage');
      expect(items[2].operation, EntryOperation.subtract);
      expect(items[2].kanal, 3);
      expect(items[2].marla, 10);

      // Line 4: Mosque
      expect(items[3].purpose, 'Mosque');
      expect(items[3].operation, EntryOperation.add);
      expect(items[3].kanal, 1);
      expect(items[3].marla, 0);

      // Line 5: Parks
      expect(items[4].purpose, 'Parks');
      expect(items[4].operation, EntryOperation.add);
      expect(items[4].kanal, 15);
      expect(items[4].marla, 8);
      expect(items[4].sarsaiCenti, 450); // 4.5 Sarsai = 450 centi-Sarsai
    });

    test('Parses delimited number format like 20-5-2', () {
      const text = 'Roads - 20-5-2';
      final items = LandDocumentParser.parseDocumentText(text);
      expect(items.length, 1);
      expect(items.first.purpose, 'Roads');
      expect(items.first.kanal, 20);
      expect(items.first.marla, 5);
      expect(items.first.sarsaiCenti, 200);
      expect(items.first.operation, EntryOperation.subtract);
    });

    test('Parses Urdu revenue terms', () {
      const text = 'کل رقبہ: 500 کنال\nسڑکیں: 20 کنال 5 مرلہ 2 سرسائی';
      final items = LandDocumentParser.parseDocumentText(text);
      expect(items.length, 2);

      expect(items[0].purpose, 'Total Area');
      expect(items[0].kanal, 500);
      expect(items[0].operation, EntryOperation.add);

      expect(items[1].purpose, 'Roads');
      expect(items[1].kanal, 20);
      expect(items[1].marla, 5);
      expect(items[1].sarsaiCenti, 200);
      expect(items[1].operation, EntryOperation.subtract);
    });
  });
}
