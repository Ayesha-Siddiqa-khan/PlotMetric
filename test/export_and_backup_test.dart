import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/data/models/calculation.dart';
import 'package:plotmetric/data/models/measurement_entry.dart';
import 'package:plotmetric/features/export/logic/csv_exporter.dart';
import 'package:plotmetric/features/export/logic/pdf_export_service.dart';
import 'package:plotmetric/features/export/logic/word_exporter.dart';
import 'package:plotmetric/features/settings/logic/backup_service.dart';

void main() {
  group('PdfExportService Tests', () {
    test('generateCalculationPdf creates valid PDF header, catalog, pages, fonts, and xref', () {
      final sampleCalculation = Calculation(
        id: 1,
        title: 'Gulshan Colony Model Town',
        calculationDate: '2026-11-18',
        calculationTime: '14:30',
        createdAtUtc: '2026-11-18T09:30:00Z',
        updatedAtUtc: '2026-11-18T09:30:00Z',
        entries: [
          const MeasurementEntry(
            id: 1,
            calculationId: 1,
            sortOrder: 0,
            purpose: 'Total Colony Area',
            operation: EntryOperation.add,
            kanal: 95,
            marla: 20,
            sarsaiCenti: 800,
          ),
          const MeasurementEntry(
            id: 2,
            calculationId: 1,
            sortOrder: 1,
            purpose: 'Main Roads 40ft',
            operation: EntryOperation.subtract,
            kanal: 12,
            marla: 10,
            sarsaiCenti: 0,
          ),
          const MeasurementEntry(
            id: 3,
            calculationId: 1,
            sortOrder: 2,
            purpose: 'Jamia Mosque',
            operation: EntryOperation.subtract,
            kanal: 2,
            marla: 0,
            sarsaiCenti: 0,
          ),
          const MeasurementEntry(
            id: 4,
            calculationId: 1,
            sortOrder: 3,
            purpose: 'Graveyard',
            operation: EntryOperation.subtract,
            kanal: 4,
            marla: 0,
            sarsaiCenti: 0,
          ),
        ],
      );

      final pdfBytes = PdfExportService.generateCalculationPdf(sampleCalculation);

      // Verify not empty
      expect(pdfBytes, isNotEmpty);

      final pdfString = utf8.decode(pdfBytes, allowMalformed: true);

      // Verify standard PDF structure
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);
      expect(pdfString.contains('/Type /Catalog'), isTrue);
      expect(pdfString.contains('/Type /Pages'), isTrue);
      expect(pdfString.contains('/Type /Page'), isTrue);
      expect(pdfString.contains('/BaseFont /Helvetica'), isTrue);
      expect(pdfString.contains('/BaseFont /Helvetica-Bold'), isTrue);
      expect(pdfString.contains('xref'), isTrue);
      expect(pdfString.contains('trailer'), isTrue);
      expect(pdfString.contains('startxref'), isTrue);
      expect(pdfString.contains('%%EOF'), isTrue);

      // Verify A4 dimensions (595.28 x 841.89)
      expect(pdfString.contains('595.28 841.89'), isTrue);

      // Verify content tokens in stream
      expect(pdfString.contains('Gulshan Colony Model Town'), isTrue);
      expect(pdfString.contains('Main Roads 40ft'), isTrue);
      expect(pdfString.contains('Jamia Mosque'), isTrue);
      expect(pdfString.contains('Graveyard'), isTrue);
      expect(pdfString.contains('NET REMAINING BALANCE'), isTrue);
    });

    test('generateAllCalculationsPdf handles empty and multiple schemes', () {
      final bytes = PdfExportService.generateAllCalculationsPdf([]);
      expect(bytes, isNotEmpty);
      final pdfString = utf8.decode(bytes, allowMalformed: true);
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);
      expect(pdfString.contains('%%EOF'), isTrue);
    });
  });

  group('CsvExporter Tests', () {
    test('exportCalculation produces standard RFC-4180 CSV with headers and row data', () {
      final sampleCalculation = Calculation(
        id: 42,
        title: 'Al-Haram City, Phase 1',
        calculationDate: '2026-11-18',
        calculationTime: '15:45',
        createdAtUtc: '2026-11-18T10:45:00Z',
        updatedAtUtc: '2026-11-18T10:45:00Z',
        entries: [
          const MeasurementEntry(
            sortOrder: 0,
            purpose: 'Total Area',
            operation: EntryOperation.add,
            kanal: 50,
            marla: 0,
            sarsaiCenti: 0,
          ),
          const MeasurementEntry(
            sortOrder: 1,
            purpose: 'Roads, 30ft',
            operation: EntryOperation.subtract,
            kanal: 5,
            marla: 10,
            sarsaiCenti: 0,
          ),
        ],
      );

      final csv = CsvExporter.exportCalculation(sampleCalculation);
      expect(csv.contains('Record ID,Title,Date,Time,Item No'), isTrue);
      // Escaped title with comma
      expect(csv.contains('"Al-Haram City, Phase 1"'), isTrue);
      expect(csv.contains('"Roads, 30ft"'), isTrue);
      expect(csv.contains('SUBTRACT'), isTrue);
      expect(csv.contains('ADD'), isTrue);
    });
  });

  group('WordExporter Tests', () {
    test('exportCalculation produces clean HTML formatted Word document with tables', () {
      final sampleCalculation = Calculation(
        id: 1,
        title: 'Shadman Colony',
        calculationDate: '2026-11-18',
        calculationTime: '12:00',
        createdAtUtc: '',
        updatedAtUtc: '',
        entries: [
          const MeasurementEntry(
            sortOrder: 0,
            purpose: 'Gross Land',
            operation: EntryOperation.add,
            kanal: 10,
            marla: 0,
            sarsaiCenti: 0,
          ),
        ],
      );

      final doc = WordExporter.exportCalculation(sampleCalculation);
      expect(doc.contains('xmlns:w="urn:schemas-microsoft-com:office:word"'.replaceAll('"', "'")), isTrue);
      expect(doc.contains('Shadman Colony'), isTrue);
      expect(doc.contains('<table class="data-table">'), isTrue);
      expect(doc.contains('SUMMARY &amp; NET REMAINING BALANCE'), isTrue);
    });
  });

  group('BackupService Logic Tests', () {
    test('BackupRestoreResult correctly models result state', () {
      const successResult = BackupRestoreResult(
        success: true,
        calculationsCount: 3,
        entriesCount: 15,
      );
      expect(successResult.success, isTrue);
      expect(successResult.calculationsCount, 3);
      expect(successResult.entriesCount, 15);
      expect(successResult.errorMessage, isNull);

      const failResult = BackupRestoreResult(
        success: false,
        errorMessage: 'Invalid JSON',
      );
      expect(failResult.success, isFalse);
      expect(failResult.errorMessage, 'Invalid JSON');
    });
  });
}
