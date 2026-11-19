import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:plotmetric/core/utils/number_formatters.dart';
import 'package:plotmetric/core/constants/scheme_catalog.dart';
import 'package:plotmetric/data/local/app_database.dart';
import 'package:plotmetric/features/export/logic/pdf_export_service.dart';
import 'package:plotmetric/features/land/logic/land_math.dart';
import 'package:plotmetric/features/schemes/logic/scheme.dart';
import 'package:plotmetric/features/schemes/logic/scheme_report.dart';
import 'package:plotmetric/features/schemes/logic/scheme_repository.dart';
import 'package:plotmetric/features/schemes/logic/scheme_scan.dart';
import 'package:plotmetric/features/schemes/logic/scheme_register_csv.dart';
import 'package:plotmetric/features/schemes/presentation/scheme_screen.dart';
import 'package:plotmetric/features/scan/logic/land_document_parser.dart';
import 'package:plotmetric/features/settings/logic/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String areaText(int amount) =>
    NumberFormatters.formatSquareFeetFromTenThousandths(amount);

HousingScheme fixture() {
  final scheme = HousingScheme()
    ..name = 'Office scheme example'
    ..owner = 'Example Developer'
    ..approval = 'APR-52'
    ..recipient = 'Municipal Office';
  for (final (description, area, k, m, s, classification) in [
    ('Total Area of Scheme', '283140', '52', '0', '0', AreaClass.gross),
    ('Residential area', '177607', '32', '12', '2', AreaClass.plot),
    ('Roads', '71670', '13', '3', '2', AreaClass.transfer),
    ('Commercial plots', '5662', '1', '0', '8', AreaClass.plot),
    ('Park and green belt', '19817', '3', '12', '7', AreaClass.transfer),
    ('Public buildings', '5662', '1', '0', '8', AreaClass.transfer),
    ('Solid waste and disposal', '2722', '0', '10', '0', AreaClass.transfer),
  ]) {
    scheme.rows.add(
      SchemeRow(
        scheme.nextRowId(),
        description: description,
        sft: area,
        kanal: k,
        marla: m,
        sarsai: s,
        percent: '1',
        classification: classification,
      ),
    );
  }
  scheme.reviewed = true;
  return scheme;
}

void main() {
  testWidgets('scheme title suggests supplied names and allows manual titles', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SchemeScreen()));
    final name = find.widgetWithText(TextField, 'Scheme name');
    await tester.enterText(name, 'IT');
    await tester.pumpAndSettle();
    expect(find.text('Ittefaq City'), findsOneWidget);
    await tester.tap(find.text('Ittefaq City'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(name).controller!.text, 'Ittefaq City');
    await tester.enterText(name, 'Al');
    await tester.pumpAndSettle();
    expect(find.text('Al-Khair Block'), findsOneWidget);
    await tester.enterText(name, 'New manually typed scheme');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(name).controller!.text,
      'New manually typed scheme',
    );
  });

  test(
    'registry CSV round trips quoted titles and fills reports only for saved schemes',
    () {
      final parsed = SchemeRegisterCsv.readNames(
        '\uFEFFSerial,Name of Housing Scheme,Owner\r\n1,"City, Phase One",Owner\r\n2,ITTEFAQ CITY,Owner\r\n3,Ittefaq City,Other\r\n',
      );
      expect(parsed, ['City, Phase One', 'ITTEFAQ CITY']);
      final saved = fixture()
        ..name = 'City, Phase One'
        ..owner = '=1+1';
      final exported = SchemeRegisterCsv.export(parsed, [saved]);
      expect(exported, contains('Name of Housing Scheme'));
      expect(exported, contains('"City, Phase One"'));
      expect(exported, contains("'=1+1"));
      expect(exported, contains('283140.00,99885.50'));
      expect(SchemeRegisterCsv.readNames(exported), parsed);
      expect(
        () => SchemeRegisterCsv.readNames('Owner,Location\nOne,Two'),
        throwsFormatException,
      );
    },
  );

  test('only checked rows are imported and a selected total stays gross', () {
    final original = fixture();
    final selected = SchemeScan.selectedRows(original.rows, {
      original.rows[0].id,
      original.rows[2].id,
    });
    expect(selected.map((row) => row.description), [
      'Total Area of Scheme',
      'Roads',
    ]);
    expect(selected.map((row) => row.classification), [
      AreaClass.gross,
      AreaClass.transfer,
    ]);
    final worksheet = HousingScheme()
      ..name = 'Selected'
      ..selectedOnly = true
      ..rows.addAll(selected);
    expect(worksheet.totals.due, 716622500);
    expect(worksheet.totals.grossLessTransferable, 2114777500);
    expect(worksheet.totals.mapDifference, isNull);
    expect(worksheet.scheduleIssues, isEmpty);
    expect(
      SchemeCatalog.suggest(SchemeCatalog.areaTitles, 'solid'),
      contains('Solid Waste Management & Disposal'),
    );
  });
  test(
    'table positions isolate Kanal from printed square feet and tolerate blank printed totals',
    () {
      TableWord word(String text, double x, double y) =>
          (text: text, x: x, y: y, height: 12);
      final rows = SchemeScan.read([
        word('S.NO', 20, 10),
        word('DESCRIPTION', 100, 10),
        word('SFT', 240, 10),
        word('K', 275, 10),
        word('M', 310, 10),
        word('S', 345, 10),
        word('%', 380, 10),
        word('1', 20, 40),
        word('TOTAL AREA', 100, 40),
        word('52', 275, 40),
        word('0', 310, 40),
        word('0', 345, 40),
        word('2', 20, 75),
        word('TOTAL ROAD AREA', 100, 75),
        word('71670', 240, 75),
        word('13', 275, 75),
        word('3', 310, 75),
        word('2', 345, 75),
        word('25.3', 380, 75),
        word('3', 20, 110),
        word('PARK', 100, 110),
        word('19817', 240, 110),
        word('12', 310, 110),
        word('7', 345, 110),
      ]);
      expect(rows[0].ready, isTrue);
      expect(rows[0].area, 2831400000);
      expect((rows[1].kanal, rows[1].marla, rows[1].sarsai), ('13', '3', '2'));
      expect(rows[1].area, 716622500);
      // The blank Kanal cell is never filled in; the printed 19817 sq ft only suggests a value.
      expect(rows[2].kanal, isEmpty);
      expect(rows[2].suggestion, isEmpty);
      expect(rows[2].needsReview, isTrue);
      expect(rows[2].area, isNull);
      expect(
        LandDocumentParser.parseDocumentText('ROAD AREA 71670 13 3 2 25.3'),
        isEmpty,
      );
    },
  );

  test(
    'older printed-square-foot approvals return to review when their amounts change',
    () {
      final scheme = fixture();
      final road = scheme.rows[2];
      scheme.evidence.add(
        TransferEvidence(
          reference: 'F-1',
          date: '2026-11-19',
          recipient: scheme.recipient,
          areaSft: '500',
          verified: true,
          allocations: {road.id: '500'},
        ),
      );
      final json = scheme.toJson()..remove('areaSource');
      final stored = (json['rows'] as List)[2] as Map<String, dynamic>;
      stored['basis'] = 'squareFeet';
      final loaded = HousingScheme.fromJson(json);
      expect(loaded.rows[2].area, 716622500);
      expect(loaded.rows[2].needsReview, isTrue);
      expect(loaded.reviewed, isFalse);
      expect(loaded.evidence.single.verified, isFalse);
    },
  );

  testWidgets(
    'an imported worksheet keeps its manual name and updates selected transfer totals',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: SchemeScreen(scanned: (rows: source.rows, crop: null)),
        ),
      );
      final name = find.widgetWithText(TextField, 'Scheme name');
      await tester.enterText(name, 'Manual scheme name');
      final roads = find.byWidgetPredicate(
        (widget) =>
            widget is Checkbox && widget.semanticLabel == 'Transferable: Roads',
      );
      expect(tester.widget<Checkbox>(roads).value, isTrue);
      await tester.ensureVisible(roads);
      await tester.tap(roads);
      await tester.pump();
      expect(tester.widget<Checkbox>(roads).value, isFalse);
      final due = find.textContaining(RegExp(r'^Due .*28,223\.25 sq ft$'));
      await tester.scrollUntilVisible(
        due,
        450,
        scrollable: find.byType(Scrollable).first,
      );
      expect(due, findsOneWidget);
      await tester.scrollUntilVisible(
        name,
        -650,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Manual scheme name',
      );
    },
  );

  test(
    'the 52 Kanal schedule reconciles and checkbox choices change the transferable balance',
    () {
      final scheme = fixture();
      expect(scheme.totals.gross, 2831400000);
      expect(scheme.totals.mapDifference, 0);
      expect(scheme.totals.due, 998855000);
      final roads = scheme.rows[2];
      expect(roads.area, 716622500);
      expect(
        SchemeArea.percentDisplay(roads.area, scheme.totals.gross),
        '25.31%',
      );
      roads.classification = AreaClass.other;
      expect(scheme.totals.due, 282232500);
      expect(scheme.totals.grossLessTransferable, 2549167500);
      expect(scheme.totals.mapDifference, 0);
    },
  );

  test(
    'verified category allocation leaves 3 Marla 4 Sarsai and keeps mortgage separate',
    () {
      final scheme = HousingScheme()
        ..name = '91K example'
        ..recipient = 'Municipal Office';
      final gross = SchemeRow(
        scheme.nextRowId(),
        description: 'Total Area of Scheme',
        kanal: '91',
        marla: '16',
        sft: '499851',
        classification: AreaClass.gross,
      );
      final plots = SchemeRow(
        scheme.nextRowId(),
        description: 'Total Area of Plot',
        kanal: '60',
        marla: '9',
        sft: '329172',
        classification: AreaClass.plot,
      );
      final roads = SchemeRow(
        scheme.nextRowId(),
        description: 'Transferable public land',
        kanal: '31',
        marla: '7',
        mortgageSft: '123.4567',
        classification: AreaClass.transfer,
      );
      scheme.rows.addAll([gross, plots, roads]);
      expect(plots.printedSft, isNot(plots.area));
      expect(plots.ready, isTrue);
      expect(gross.area! - plots.area!, SchemeArea.land('31', '7', '0'));
      expect(scheme.totals.mapDifference, 0);
      final documented = SchemeArea.land('31', '3', '5')!;
      final fard = TransferEvidence(
        reference: 'F-31',
        date: '2026-11-19',
        recipient: scheme.recipient,
        areaSft: areaText(documented),
        verified: true,
      );
      scheme.evidence.add(fard);
      expect(scheme.totals.verified, 0);
      fard.allocations[roads.id] = '999999';
      expect(scheme.evidenceIssue(fard), contains('exceed'));
      fard.allocations[roads.id] = fard.areaSft;
      expect(scheme.totals.remaining, SchemeArea.land('0', '3', '4'));
      expect(scheme.totals.mortgage, 1234567);
      final original = scheme.totals.remaining;
      roads.mortgageSft = '300';
      expect(scheme.totals.remaining, original);
      scheme.evidence.add(
        TransferEvidence(
          reference: ' f-31 ',
          date: '2026-11-19',
          recipient: scheme.recipient,
        ),
      );
      expect(scheme.totals.verified, 0);
    },
  );

  test('excess transfer in one category cannot settle another', () {
    final scheme = fixture();
    final park = scheme.rows.firstWhere(
      (row) => row.description.startsWith('Park'),
    );
    scheme.evidence.add(
      TransferEvidence(
        reference: 'M-1',
        date: '2026-11-19',
        recipient: scheme.recipient,
        areaSft: '25000',
        verified: true,
        allocations: {park.id: '25000'},
      ),
    );
    expect(scheme.totals.excess(park), 51862500);
    expect(scheme.totals.remaining, scheme.totals.due - park.area!);
  });

  test('fractional Land Calculator entry is normalized once', () {
    final units = LandMath.parseAreaInput('5', '۱۰٫۵', '');
    final result = LandMath.centiSarsaiToComposite(units!);
    expect((result.kanal, result.marla, result.sarsaiCenti), (5, 10, 450));
    expect(LandMath.parseAreaInput('5', '10.555', ''), isNull);
    final imported = LandDocumentParser.parseDocumentText(
      'Total Area: 5 Kanal 10.5 Marla',
    ).single;
    expect(
      (imported.kanal, imported.marla, imported.sarsaiCenti),
      (5, 10, 450),
    );
  });

  test(
    'geometry preserves wrapped labels and flags missing or ambiguous values',
    () {
      TableWord word(String text, double x, double y) =>
          (text: text, x: x, y: y, height: 12);
      final rows = SchemeScan.read([
        word('DES', 100, 10),
        word('SFT', 240, 10),
        word('K', 280, 10),
        word('M/S', 320, 10),
        word('TOTAL AREA OF SCHEME', 100, 35),
        word('499851', 240, 36),
        word('91', 280, 35),
        word('16.0', 320, 35),
        word('MASJID COMMERCIAL', 100, 60),
        word('4998', 240, 60),
        word('0', 280, 60),
        word('18.5', 320, 60),
        word('BLOCK A', 100, 77),
        word('ROADS', 100, 100),
        word('25', 280, 100),
      ]);
      expect(rows.length, 3);
      expect(rows[0].classification, AreaClass.gross);
      // An M/S column reads "16.0" as 16 Marla 0 Sarsai and "18.5" as 18 Marla 5 Sarsai.
      expect((rows[0].marla, rows[0].sarsai), ('16', '0'));
      expect(rows[1].description, 'MASJID COMMERCIAL BLOCK A');
      expect((rows[1].marla, rows[1].sarsai), ('18', '5'));
      expect(rows[1].classification, AreaClass.review);
      expect(rows[2].needsReview, isTrue);
    },
  );

  test(
    'serial numbers keep multiline public buildings and disposal in their own rows',
    () {
      TableWord word(String text, double x, double y) =>
          (text: text, x: x, y: y, height: 12);
      final rows = SchemeScan.read([
        word('S.NO', 20, 10),
        word('DES', 110, 10),
        word('SFT', 240, 10),
        word('K', 280, 10),
        word('5', 20, 38),
        word('PARK & GREEN BELT', 110, 38),
        word('19817', 240, 38),
        word('3', 280, 38),
        word('6', 20, 66),
        word('PUBLIC BUILDING MOSQUE', 110, 66),
        word('DISPENSARY', 110, 77),
        word('5662', 240, 77),
        word('1', 280, 77),
        word('7', 20, 98),
        word('SOLID WASTE', 110, 98),
        word('AND DISPOSAL', 110, 110),
        word('2722', 240, 110),
        word('0', 280, 110),
      ]);
      expect(rows.map((row) => row.description), [
        'PARK & GREEN BELT',
        'PUBLIC BUILDING MOSQUE DISPENSARY',
        'SOLID WASTE AND DISPOSAL',
      ]);
      expect(rows.map((row) => row.sft), ['', '', '']); // square feet are calculated, not read
    },
  );

  test(
    'Excel round trip keeps editable numeric cells and PDF uses the same report',
    () {
      final scheme = fixture();
      scheme.columns
        ..remove(ScheduleColumn.type)
        ..insert(0, ScheduleColumn.type);
      scheme.columnNames[ScheduleColumn.type] = 'Land use';
      scheme.hiddenColumns.add(ScheduleColumn.percent);
      scheme.rows[2].mortgageSft = '345.6789';
      final report = SchemeReport(scheme);
      final workbook = Excel.decodeBytes(report.excelBytes());
      expect(
        workbook.tables.keys,
        unorderedEquals(['Scheme Report', 'Transfer Evidence']),
      );
      final rows = workbook['Scheme Report'].rows;
      final heading = rows.firstWhere(
        (row) => row.first?.value.toString() == 'Land use',
      );
      expect(
        heading.map((cell) => cell?.value.toString()),
        isNot(contains('%')),
      );
      final due = rows.firstWhere(
        (row) => row.first?.value.toString() == 'Due (sq ft)',
      );
      expect(due[1]?.value, DoubleCellValue(99885.5));
      final pdf = latin1.decode(PdfExportService.generateSchemePdf(report));
      expect(pdf, startsWith('%PDF-'));
      expect(pdf, contains('99885.5'));
      expect(pdf, contains('345.6789'));
    },
  );

  test(
    'v1 database upgrades, register deduplicates, and v2 backup restores images and layout',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final build = await Directory('build').create(recursive: true);
      final folder = await build.createTemp('scheme_db_test_');
      addTearDown(() async {
        await AppDatabase.instance.close();
        await folder.delete(recursive: true);
      });
      await databaseFactory.setDatabasesPath(folder.absolute.path);
      final legacy = await databaseFactory.openDatabase(
        p.join(folder.absolute.path, AppDatabase.databaseName),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE calculations (id INTEGER PRIMARY KEY, title TEXT, calculation_date TEXT, calculation_time TEXT, created_at_utc TEXT, updated_at_utc TEXT)',
            );
            await db.execute(
              'CREATE TABLE measurement_entries (id INTEGER PRIMARY KEY, calculation_id INTEGER, sort_order INTEGER, purpose TEXT, operation TEXT, kanal INTEGER, marla INTEGER, sarsai_centi INTEGER)',
            );
            await db.insert('calculations', {'title': 'Legacy record'});
          },
        ),
      );
      await legacy.close();
      final repo = SchemeRepository();
      final scheme = fixture();
      scheme.scheduleCrop = base64Encode([1, 2, 3]);
      scheme.columnNames[ScheduleColumn.description] = 'Map description';
      await repo.save(scheme);
      await repo.addNames(['Alpha Scheme', ' alpha scheme ', 'Beta Scheme']);
      final registerNames = await repo.names();
      expect(
        registerNames,
        unorderedEquals([
          ...SchemeCatalog.colonies,
          scheme.name,
          'Alpha Scheme',
          'Beta Scheme',
        ]),
      );
      expect((await repo.list('example developer')).single.id, scheme.id);
      expect((await repo.load(scheme.id!)).scheduleCrop, scheme.scheduleCrop);
      final backup = BackupService();
      final json = await backup.exportBackupJson();
      expect((jsonDecode(json) as Map)['total_calculations'], 1);
      final restored = await backup.restoreFromJson(json, replaceAll: true);
      expect(restored.success, isTrue, reason: restored.errorMessage);
      expect(restored.schemesCount, 1);
      final fromBackup = (await repo.all()).single;
      expect(fromBackup.scheduleCrop, scheme.scheduleCrop);
      expect(
        fromBackup.columnNames[ScheduleColumn.description],
        'Map description',
      );
      expect(await repo.names(), registerNames);
      final older = await backup.restoreFromJson(
        '{"app":"PlotMetric","format_version":1,"calculations":[]}',
        replaceAll: true,
      );
      expect(older.success, isTrue);
      expect(await repo.all(), hasLength(1));
    },
  );

  test(
    'missing M/S headers are inferred and ticked rows count toward the total',
    () {
      TableWord word(String text, double x, double y) =>
          (text: text, x: x, y: y, height: 45);
      final rows = SchemeScan.read([
        word('DESCRIPTION', 500, 10),
        word('SFT', 1100, 10),
        word('K', 1290, 10),
        word('TOTAL AREA', 500, 100),
        word('283140', 1100, 100),
        word('52', 1290, 100),
        word('O', 1440, 100),
        word('O', 1555, 100),
        word('100', 1730, 100),
        word('TOTAL ROAD AREA', 500, 200),
        word('71670', 1100, 200),
        word('13', 1270, 200),
        word('3', 1440, 200),
        word('2', 1555, 200),
        word('25.3', 1730, 200),
      ]);
      expect(rows.length, 2);
      expect([rows[0].kanal, rows[0].marla, rows[0].sarsai], ['52', '0', '0']);
      expect([rows[1].kanal, rows[1].marla, rows[1].sarsai], ['13', '3', '2']);
      final selected = SchemeScan.selectedRows(rows, {rows[1].id});
      final scheme = HousingScheme()..rows.addAll(selected);
      expect(scheme.totals.due, selected.single.area);
      expect(scheme.totals.due, greaterThan(0));
    },
  );

  test(
    'tilted photo: split header, missing SFT header and a damaged serial still give one row per line',
    () {
      TableWord word(String text, double x, double y) =>
          (text: text, x: x, y: y, height: 16);
      final rows = SchemeScan.read([
        word('TOTAL AREA OF SCHEME', 300, 30), word('499851', 478, 30),
        word('91', 620, 23), word('16', 684, 24),
        // The header cells fall on two lines and SFT and % are unreadable.
        word('K', 630, 80),
        word('M', 685, 82),
        word('S.NO', 141, 86),
        word('DES', 297, 91),
        word('1.', 164, 136),
        word('TOTAL AREA OF PLOT', 330, 140),
        word('329172.', 511, 139),
        word('60', 633, 137), word('09', 691, 137), word('5.87', 753, 139),
        word('2.', 164, 195),
        word('MASJID COMMERICAL', 280, 196),
        word('4998', 529, 195),
        word('o', 639, 190), word('18.5', 701, 190), word('1', 743, 190),
        // Row 3 lost its serial number and is damaged by a hole.
        word('TOTAL.AGEOF--ROAD', 301, 238), word('1403', 493, 238),
        word('26', 638, 238), word('{5.5', 699, 239), word('28.07', 752, 240),
        word('4', 160, 285),
        word('PARK AND GAREEN BELT', 300, 286),
        word('25371', 520, 288),
        word('5.06', 763, 287), word('4', 644, 296), word('13', 692, 296),
      ]);
      // The total printed above the table is row 1; the other rows follow.
      expect(rows.map((row) => row.description), [
        'TOTAL AREA OF SCHEME',
        'TOTAL AREA OF PLOT',
        'MASJID COMMERCIAL',
        'TOTAL AREA OF ROAD',
        'PARK AND GREEN BELT',
      ]);
      expect(rows.map((row) => [row.kanal, row.marla, row.sarsai].join('-')), [
        '91-16-',
        '60-09-',
        '0-18.5-',
        '26-15.5-',
        '4-13-',
      ]);
      expect(rows.map((row) => row.sft), ['', '', '', '', '']);
      // The percentage is calculated from the areas, so none is read from the photo.
      expect(rows.map((row) => row.percent), ['', '', '', '', '']);
      expect(rows[3].needsReview, isTrue); // "{5.5" was a guess
      expect(rows[4].needsReview, isFalse);
    },
  );

  test(
    'printed square feet are ignored: Kanal/Marla/Sarsai come only from their own columns',
    () {
      TableWord word(String text, double x, double y) =>
          (text: text, x: x, y: y, height: 12);
      final rows = SchemeScan.read([
        word('S.NO', 20, 10),
        word('DESCRIPTION', 100, 10),
        word('SFT', 240, 10),
        word('K', 275, 10),
        word('M', 310, 10),
        word('S', 345, 10),
        word('%', 380, 10),
        word('1', 20, 40), word('TOTAL AREA', 100, 40), word('283140', 240, 40),
        word('52', 275, 40),
        word('0', 310, 40),
        word('0', 345, 40),
        word('100', 380, 40),
        // Marla (12) was not read, and the 6 of 62.74 was lost.
        word('2', 20, 75),
        word('RESIDENTIAL AREA', 100, 75),
        word('177607', 240, 75),
        word('32', 275, 75), word('2', 345, 75), word('2.74', 380, 75),
        // Nothing but the square feet was read.
        word('3', 20, 110),
        word('PARK', 100, 110),
        word('19817', 240, 110),
        word('7', 380, 110),
        // K/M/S disagree with the printed square feet by far more than rounding.
        word('4', 20, 145),
        word('COMMERCIAL AREA', 100, 145),
        word('5662', 240, 145),
        word('9', 275, 145),
        word('0', 310, 145),
        word('8', 345, 145),
        word('2', 380, 145),
      ]);
      // Unread cells stay empty; the printed square feet are never used to fill or question them.
      expect((rows[1].kanal, rows[1].marla, rows[1].sarsai), ('32', '', '2'));
      expect(rows[1].needsReview, isTrue);
      expect((rows[2].kanal, rows[2].marla, rows[2].sarsai), ('', '', ''));
      expect(rows[2].needsReview, isTrue);
      expect((rows[3].kanal, rows[3].marla, rows[3].sarsai), ('9', '0', '8'));
      for (final row in rows) {
        expect(row.sft, isEmpty);
        expect(row.suggestion, isEmpty);
        expect(row.sftConflict, isFalse);
        expect(row.percent, isEmpty); // calculated by the app
      }
      expect(rows[0].needsReview, isFalse);
    },
  );

  test('descriptions are rebuilt from the key word that can still be read', () {
    expect(
      SchemeScan.fixWords('MASJID COMMERICAL 4080 M-15.S-0 .1266M-4.S-4.1/2'),
      'MASJID COMMERCIAL',
    );
    expect(SchemeScan.fixWords('TOT.ALAÄEAOF.-ROAD'), 'TOTAL AREA OF ROAD');
    expect(SchemeScan.fixWords('IOXALAAÄE&OF-ROAD'), 'TOTAL AREA OF ROAD');
    expect(SchemeScan.fixWords('PARR'), 'PARK');
    expect(SchemeScan.fixWords('MASJID COUME├åCAL'), 'MASJID COMMERCIAL');
    // Real wording is left alone.
    expect(
      SchemeScan.fixWords('MASJID COMMERCIAL BLOCK A'),
      'MASJID COMMERCIAL BLOCK A',
    );
    expect(
      SchemeScan.fixWords('PUBLIC BUILDING MOSQUE (17M-8S) DISPENSARY (3M)'),
      'PUBLIC BUILDING MOSQUE (17M-8S) DISPENSARY (3M)',
    );
  });

  test(
    'a total written above the table moves to row 1, the legend below is ignored, and M/S reads Marla.Sarsai',
    () {
      TableWord word(String text, double x, double y) =>
          (text: text, x: x, y: y, height: 22);
      final rows = SchemeScan.read([
        word('TOTAL', 201, 72),
        word('AREA', 302, 74),
        word('OF', 374, 74),
        word('SCHEME', 466, 74),
        word('499851', 603, 73), word('91', 805, 64), word('16', 897, 66),
        word('S.NO', 120, 150),
        word('DES', 343, 158),
        word('SFT', 650, 150),
        word('K', 819, 145),
        word('M', 898, 147),
        word('1.', 153, 223),
        word('TOTAL AREA OF PLOT', 400, 229),
        word('329172', 653, 231),
        word('60', 822, 226),
        word('09', 905, 227),
        word('2', 148, 307),
        word('MASJID COMMERICAL', 330, 308),
        word('4998', 673, 309),
        word('O', 831, 302),
        word('18.5', 920, 302),
        word('4', 147, 435),
        word('PARK AND GAREEN BELT', 330, 436),
        word('25371', 661, 442),
        word('4', 838, 454),
        word('13', 907, 454),
        word('5', 145, 519),
        word('TOTAL AREA OF SCHEME', 400, 520),
        word('499851', 656, 524),
        word('91', 821, 522),
        word('16', 925, 522),
        // The legend under the table.
        word('S.NO', 578, 624),
        word('LEGEND', 768, 624),
        word('H.T', 633, 651),
        word('POLE', 686, 653),
        word('1', 586, 656),
        word('L.T', 635, 686),
        word('POLE', 687, 687),
        word('2', 586, 688),
      ]);
      expect(rows.map((row) => row.description), [
        'TOTAL AREA OF SCHEME',
        'TOTAL AREA OF PLOT',
        'MASJID COMMERCIAL',
        'PARK AND GREEN BELT',
      ]);
      expect(rows.first.classification, AreaClass.gross);
      expect((rows.first.kanal, rows.first.marla), ('91', '16'));
      expect(rows.map((row) => row.id), [1, 2, 3, 4]);
      expect(
        rows.where((row) => row.classification == AreaClass.gross),
        hasLength(1),
      );
    },
  );

  test(
    'an M/S column with a % that could not be read keeps Marla.Sarsai apart from the %',
    () {
      TableWord word(String text, double x, double y) =>
          (text: text, x: x, y: y, height: 12);
      final rows = SchemeScan.read([
        word('S.NO', 36, 52),
        word('DES', 138, 52),
        word('SFT', 246, 53),
        word('K', 286, 53),
        word('MIS', 329, 53),
        word('TOTAL AREA OF PLOT', 140, 75),
        word('329172', 246, 75),
        word('59', 290, 75),
        word('15.0', 330, 75),
        word('61', 384, 75),
        word('MASJID COMMERICAL', 140, 107),
        word('5336', 247, 107),
        word('o', 286, 107),
        word("19.4½", 331, 107),
        word('1', 380, 107),
        word('TOTAL AREA OF ROAD', 140, 137),
        word('174654', 243, 137),
        word('32', 290, 137),
        word('1.4%', 331, 136),
        word('32.25', 385, 137),
        word('PARK', 83, 169),
        word('28304', 250, 169),
        word('5', 287, 169),
        word('4.0', 326, 169),
        word('5.25', 385, 169),
      ]);
      expect(
        [for (final row in rows) '${row.kanal}-${row.marla}-${row.sarsai}'],
        ['59-15-0', '0-19-4.5', '32-1-4.5', '5-4-0'],
      );
      expect(rows.map((row) => row.description).last, 'PARK');
    },
  );
}
