import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/data/local/app_database.dart';
import 'package:plotmetric/features/approved_land/logic/approved_land.dart';
import 'package:plotmetric/features/approved_land/logic/approved_land_export.dart';
import 'package:plotmetric/features/approved_land/presentation/approved_land_screen.dart';
import 'package:plotmetric/features/export/logic/file_save_helper.dart';
import 'package:plotmetric/features/export/logic/table_formats.dart';
import 'package:plotmetric/features/export/presentation/table_export_dialog.dart';
import 'package:plotmetric/features/schemes/logic/schedule_export.dart';
import 'package:plotmetric/features/schemes/logic/scheme.dart';
import 'package:plotmetric/features/schemes/logic/scheme_repository.dart';
import 'package:plotmetric/features/schemes/presentation/saved_schedules_panel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ApprovedLandEntry colony(int serial, String name, {String total = '98K-0M-0S'}) => ApprovedLandEntry(
  serial: serial,
  name: name,
  owner: 'Owner, with comma',
  mouza: 'Chak "13/G"',
  totalArea: total,
  remaining: '18K-12M-5S',
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('Approved Land rows and columns', () {
    final entries = [colony(1, 'Al khair'), colony(2, 'Model Town', total: '91K 16M')];

    test('areas are always K-M-S and empty areas show a dash', () {
      expect(ApprovedLandColumn.totalArea.valueOf(entries[1]), '91K-16M-0S');
      expect(ApprovedLandColumn.transferred.valueOf(entries[0]), '-');
      expect(ApprovedLandColumn.remaining.valueOf(entries[0]), '18K-12M-5S');
      expect(ApprovedLandColumn.owner.valueOf(entries[0]), 'Owner, with comma');
    });

    test('CSV keeps only the chosen columns, quotes commas and quotes, and starts with a BOM', () {
      final columns = ApprovedLandExport.columns;
      final chosen = [0, 1, 3, 4].map((i) => columns[i]).toList();
      final group = ApprovedLandExport.group(entries);
      final rows = [
        for (final row in group.rows) [for (final i in [0, 1, 3, 4]) row[i]],
      ];
      final bytes = TableFormats.csv([for (final c in chosen) c.label], rows);
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]); // byte-order mark for Excel
      final lines = utf8.decode(bytes).trim().split('\r\n');
      expect(lines.first, 'Sr.No.,Name of Housing Scheme,Name of Mouza (s) / Address / Road,Total Area (K-M-S)');
      expect(lines[1], '1,Al khair,"Chak ""13/G""",98K-0M-0S');
      expect(lines, hasLength(3));
    });

    test('PDF is a landscape A4 table with the chosen text, a header on every page and page numbers', () {
      final many = [for (var i = 1; i <= 60; i++) colony(i, 'Colony number $i')];
      final bytes = TableFormats.pdf(
        title: ApprovedLandExport.title,
        subtitle: ApprovedLandExport.subtitle,
        columns: ApprovedLandExport.columns,
        headers: [for (final c in ApprovedLandExport.columns) c.label],
        rows: ApprovedLandExport.group(many).rows,
      );
      final pdf = latin1.decode(bytes);
      expect(pdf, startsWith('%PDF-'));
      expect(pdf, contains('/MediaBox [0 0 841.89 595.28]'));
      expect(pdf, contains('Colony number 60'));
      expect(pdf, contains('Page 1 of '));
      final pages = RegExp(r'/Type /Page ').allMatches(pdf).length;
      expect(pages, greaterThan(1));
      expect(RegExp(r'Developers[)] Tj').allMatches(pdf).length, greaterThanOrEqualTo(pages)); // header repeated on every page
    });

    test('Word and WhatsApp text carry the same rows', () {
      final columns = ApprovedLandExport.columns;
      final rows = ApprovedLandExport.group(entries).rows;
      final word = utf8.decode(
        TableFormats.word(
          title: ApprovedLandExport.title,
          columns: columns,
          headers: [for (final c in columns) c.label],
          rows: rows,
        ),
      );
      expect(word, contains('landscape'));
      expect(word, contains('<td>Model Town</td>'));
      expect(word, contains('Chak &quot;13/G&quot;'));
      final chat = TableFormats.chatText(
        title: 'Register',
        columns: columns,
        groups: [ApprovedLandExport.group(entries)],
        columnIndexes: [1, 4],
      );
      expect(chat, contains('*Al khair*'));
      expect(chat, contains('Total Area (K-M-S): 91K-16M-0S'));
      expect(chat, isNot(contains('Owner')));
    });
  });

  group('saved schedules', () {
    test('square feet and % are calculated from Kanal/Marla/Sarsai against the Total Area row', () {
      final rows = [
        SchemeRow(1, description: 'TOTAL AREA', kanal: '52', marla: '0', sarsai: '0', classification: AreaClass.gross),
        SchemeRow(2, description: 'TOTAL ROAD AREA', kanal: '13', marla: '3', sarsai: '2', classification: AreaClass.transfer),
        SchemeRow(3, description: 'PARK', classification: AreaClass.transfer),
      ];
      final group = scheduleGroup('Test colony', rows, {2});
      expect(group.rows[0][5], '283,140.00');
      expect(group.rows[0][6], '100.00%');
      expect(group.rows[1][5], '71,662.25');
      expect(group.rows[1][6], '25.31%');
      expect(group.rows[1][8], 'Yes');
      expect(group.rows[2].sublist(2, 7), ['-', '-', '-', '-', '-']); // nothing invented for unread cells
      expect(group.rows[2][8], 'No');
    });
  });

  group('export dialog', () {
    const columns = [ExportColumn('a', 'Name'), ExportColumn('b', 'Area', centred: true), ExportColumn('c', 'Note')];
    final groups = [
      const ExportGroup('First colony', [['one', '1K', 'x'], ['two', '2K', 'y']]),
      const ExportGroup('Second colony', [['three', '3K', 'z']]),
    ];

    testWidgets('choose columns, one combined file or a file for each, and send a chat message', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saved = <(String, Uint8List)>[];
      final texts = <String>[];
      final shares = <(String, bool)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableExportDialog(
              title: 'Test export',
              subtitle: 'sub',
              columns: columns,
              groups: groups,
              fileStem: 'Test',
              saver: (name, bytes) async {
                saved.add((name, bytes));
                return ExportFileResult(success: true, filePath: '/tmp/$name', fileName: name);
              },
              share: (path, {whatsApp = false}) async {
                shares.add((path, whatsApp));
                return true;
              },
              open: (path) async => true,
              sendText: (text) async => texts.add(text),
            ),
          ),
        ),
      );
      expect(find.textContaining('3 rows from 2 schedules'), findsOneWidget);
      // Drop the Note column.
      await tester.tap(find.widgetWithText(FilterChip, 'Note'));
      await tester.pump();

      // One combined CSV: a "Schedule" column is added and all three rows are in it.
      await tester.tap(find.widgetWithText(FilledButton, 'CSV'));
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      final combined = utf8.decode(saved.single.$2).trim().split('\r\n');
      expect(combined.first, 'Schedule,Name,Area');
      expect(combined, ['Schedule,Name,Area', 'First colony,one,1K', 'First colony,two,2K', 'Second colony,three,3K']);
      expect(saved.single.$1, endsWith('.csv'));

      // A separate file for each schedule.
      saved.clear();
      await tester.tap(find.text('A separate file for each schedule'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'CSV'));
      await tester.pumpAndSettle();
      expect(saved.map((f) => f.$1.split('_').first), ['First', 'Second']);
      expect(utf8.decode(saved[1].$2).trim().split('\r\n'), ['Name,Area', 'three,3K']);

      // PDF and Word are real files too.
      saved.clear();
      await tester.tap(find.widgetWithText(FilledButton, 'PDF'));
      await tester.pumpAndSettle();
      expect(saved, hasLength(2));
      expect(latin1.decode(saved.first.$2), startsWith('%PDF-'));
      saved.clear();
      await tester.tap(find.widgetWithText(FilledButton, 'Word'));
      await tester.pumpAndSettle();
      expect(utf8.decode(saved.first.$2), contains('<table>'));
      expect(saved.first.$1, endsWith('.doc'));

      // Share, and send the file on WhatsApp.
      await tester.tap(find.byTooltip('Share').first);
      await tester.tap(find.byTooltip('Send this file on WhatsApp').first);
      await tester.pump();
      expect(shares.map((s) => s.$2), [false, true]);

      // The chat message uses only the chosen columns.
      await tester.tap(find.text('WhatsApp message'));
      await tester.pumpAndSettle();
      expect(texts.single, contains('*one*'));
      expect(texts.single, contains('Area: 1K'));
      expect(texts.single, isNot(contains('Note')));
    });

    testWidgets('no column chosen is refused', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableExportDialog(
              title: 'T',
              columns: columns,
              groups: groups,
              fileStem: 'T',
              saver: (name, bytes) async => throw StateError('must not save'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('None'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'PDF'));
      await tester.pump();
      expect(find.text('Choose at least one column.'), findsOneWidget);
    });
  });

  group('pages', () {
    late Directory folder;

    Future<void> openDatabase(WidgetTester tester) async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      folder = (await tester.runAsync(() async {
        final build = await Directory('build').create(recursive: true);
        final created = await build.createTemp('export_pages_');
        await databaseFactory.setDatabasesPath(created.absolute.path);
        return created;
      }))!;
      addTearDown(() async {
        await tester.runAsync(() async {
          await AppDatabase.instance.close();
          await folder.delete(recursive: true);
        });
      });
    }

    testWidgets('Approved Land: tick rows, then export exactly those rows', (tester) async {
      tester.view.physicalSize = const Size(1800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openDatabase(tester);
      await tester.pumpWidget(const MaterialApp(home: ApprovedLandScreen()));
      await settle(tester);
      expect(find.text('Export'), findsOneWidget);
      // Tick the first two colonies (the first checkbox selects every row).
      final boxes = find.byType(Checkbox);
      await tester.tap(boxes.at(1));
      await tester.tap(boxes.at(2));
      await tester.pump();
      expect(find.text('Export (2)'), findsOneWidget);
      await tester.tap(find.text('Export (2)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 rows from the selection'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Mortgage Deed (K-M-S)'), findsOneWidget);
    });

    testWidgets('Records: saved schedules are listed, can be ticked and exported', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openDatabase(tester);
      await tester.runAsync(() async {
        final repo = SchemeRepository();
        for (final name in ['Alpha colony', 'Beta colony']) {
          final scheme = HousingScheme()..name = name;
          scheme.scanRows.addAll([
            SchemeRow(1, description: 'TOTAL AREA', kanal: '52', marla: '0', sarsai: '0', classification: AreaClass.gross),
            SchemeRow(2, description: 'ROADS', kanal: '13', marla: '3', sarsai: '2', classification: AreaClass.transfer),
          ]);
          scheme.scanChecked.add(2);
          await repo.save(scheme);
        }
      });
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SavedSchedulesPanel()))));
      await settle(tester);
      expect(find.text('Saved area schedules (2)'), findsOneWidget);
      expect(find.text('Alpha colony'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('Export (1)'), findsOneWidget);
      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.tap(find.text('Export (2)'));
      await settle(tester);
      expect(find.textContaining('4 rows from 2 schedules'), findsOneWidget);
      expect(find.text('A separate file for each schedule'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Calculated Sq Ft'), findsOneWidget);
    });
  });
}
