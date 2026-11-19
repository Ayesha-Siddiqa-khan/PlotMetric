import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/data/local/app_database.dart';
import 'package:plotmetric/features/approved_land/logic/approved_land_repository.dart';
import 'package:plotmetric/features/approved_land/presentation/approved_land_screen.dart';
import 'package:plotmetric/features/schemes/logic/scheme_repository.dart';
import 'package:plotmetric/features/schemes/presentation/scheme_scan_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('tap a colony, scan result is saved to Approved Land, and reopening restores it', (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final folder = (await tester.runAsync(() async {
      final build = await Directory('build').create(recursive: true);
      final created = await build.createTemp('approved_flow_');
      await databaseFactory.setDatabasesPath(created.absolute.path);
      return created;
    }))!;
    addTearDown(() async {
      await tester.runAsync(() async {
        await AppDatabase.instance.close();
        await folder.delete(recursive: true);
      });
    });
    await tester.pumpWidget(const MaterialApp(home: ApprovedLandScreen()));
    await settle(tester);
    expect(find.text('Approved Land'), findsOneWidget);
    expect(find.text('Al khair housing colony'), findsOneWidget);
    expect(find.text('98K-0M-0S'), findsWidgets);

    // A new colony can be added from the button next to the search box.
    await tester.tap(find.text('New colony'));
    await tester.pumpAndSettle();
    expect(find.text('Add colony'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Search narrows the list.
    await tester.enterText(find.widgetWithText(TextField, 'Search by colony, owner, mouza or area'), 'model town');
    await tester.pump();
    expect(find.text('Al khair housing colony'), findsNothing);
    expect(find.text('MODEL TOWN'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Search by colony, owner, mouza or area'), '');
    await tester.pump();

    // Tapping the name opens the scan page with the name and total area filled in.
    await tester.tap(find.text('Al khair housing colony'));
    await settle(tester);
    expect(find.byType(SchemeScanScreen), findsOneWidget);
    expect(find.text('Al khair housing colony'), findsWidgets);
    expect(find.textContaining('Approved Land total area: 98K-0M-0S'), findsOneWidget);

    // Add one transferable row and tick it.
    await tester.tap(find.text('Add row'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Area title').first, 'ROADS');
    await tester.enterText(find.widgetWithText(TextField, 'Kanal'), '13');
    await tester.enterText(find.widgetWithText(TextField, 'Marla'), '3');
    await tester.enterText(find.widgetWithText(TextField, 'Sarsai'), '2');
    await tester.tap(find.text('Apply row'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kanal'), '5');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);

    final repo = ApprovedLandRepository();
    final row = (await tester.runAsync(() => repo.byName('Al khair housing colony')))!;
    expect(row.transferTotal, '13K-3M-2S');
    expect(row.transferred, '5K-0M-0S');
    expect(row.remaining, '8K-3M-2S');
    expect(row.totalArea, '98K-0M-0S');
    expect(row.schemeId, isNotNull);
    final saved = await tester.runAsync(() => SchemeRepository().list());
    expect(saved, hasLength(1)); // also kept as its own Records entry

    // Back on the register the new figures show.
    await tester.pageBack();
    await settle(tester);
    expect(find.text('8K-3M-2S'), findsWidgets);

    // Opening the colony again reloads the earlier scan instead of starting empty, and saving again does not duplicate it.
    await tester.tap(find.text('Al khair housing colony'));
    await settle(tester);
    expect(find.text('ROADS'), findsNWidgets(2)); // table row and selected-area summary
    expect(find.text('Remaining'), findsOneWidget);
    await tester.tap(find.text('Saved').first);
    await settle(tester);
    final again = await tester.runAsync(() => SchemeRepository().list());
    expect(again, hasLength(1));
  });

  testWidgets('register fits a phone: centred area columns and sideways scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final folder = (await tester.runAsync(() async {
      final build = await Directory('build').create(recursive: true);
      final created = await build.createTemp('approved_phone_');
      await databaseFactory.setDatabasesPath(created.absolute.path);
      return created;
    }))!;
    addTearDown(() async {
      await tester.runAsync(() async {
        await AppDatabase.instance.close();
        await folder.delete(recursive: true);
      });
    });
    await tester.pumpWidget(const MaterialApp(home: ApprovedLandScreen()));
    await settle(tester);
    // The mortgage column starts off screen and is reached by scrolling sideways.
    final mortgage = find.text('Mortgage\nDeed (K-M-S)');
    expect(tester.getTopLeft(mortgage).dx, greaterThan(390));
    await tester.dragFrom(const Offset(200, 400), const Offset(-1200, 0));
    await tester.pump();
    expect(tester.getTopLeft(mortgage).dx, lessThan(390));
    // Area text is centred in its column.
    final cell = find.text('98K-0M-0S');
    final column = tester.getRect(find.ancestor(of: cell, matching: find.byType(SizedBox)).first);
    expect((tester.getCenter(cell).dx - column.center.dx).abs(), lessThan(2));
  });
}
