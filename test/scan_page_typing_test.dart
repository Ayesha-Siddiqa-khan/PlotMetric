import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/features/approved_land/logic/approved_land.dart';
import 'package:plotmetric/features/schemes/presentation/scheme_scan_screen.dart';

void main() {
  testWidgets('typing in already transferred works on the full scan page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: SchemeScanScreen(tab: true)),
    );
    await tester.tap(find.text('Add row'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Area title').first,
      'ROAD',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Kanal'), '13');
    await tester.enterText(find.widgetWithText(TextField, 'Marla'), '3');
    await tester.enterText(find.widgetWithText(TextField, 'Sarsai'), '2');
    await tester.tap(find.text('Apply row'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextField, 'Kanal');
    expect(field, findsOneWidget);
    await tester.tap(field);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(editable).focusNode.hasFocus,
      isTrue,
      reason: 'field lost focus after tap',
    );
    expect(tester.testTextInput.hasAnyClients, isTrue);
    tester.testTextInput.enterText('5');
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<EditableText>(editable).focusNode.hasFocus,
      isTrue,
      reason: 'focus lost after typing',
    );
    expect(tester.widget<TextField>(field).controller!.text, '5');
    expect(find.text('Remaining'), findsOneWidget);
  });

  testWidgets(
    'row editor: square feet only convert into Kanal/Marla/Sarsai, and a typed % overrides the calculated one',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: SchemeScanScreen(tab: true)),
      );
      await tester.tap(find.text('Add row'));
      await tester.pumpAndSettle();
      TextField field(String label) =>
          tester.widget<TextField>(find.widgetWithText(TextField, label).last);

      // Typing square feet fills Kanal / Marla / Sarsai (the square feet are not stored).
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Square feet (optional: fills Kanal/Marla/Sarsai)',
        ),
        '71670',
      );
      await tester.pump();
      expect(field('Kanal').controller!.text, '13');
      expect(field('Marla').controller!.text, '3');
      // Nothing asks for a decision: the app calculates the square feet from Kanal/Marla/Sarsai.
      await tester.enterText(find.widgetWithText(TextField, 'Kanal'), '14');
      await tester.pump();
      expect(
        find.text('The scanned figures disagree. Choose which one to trust.'),
        findsNothing,
      );
      await tester.enterText(find.widgetWithText(TextField, 'Kanal'), '13');
      await tester.enterText(
        find.widgetWithText(TextField, '% (empty = calculated)'),
        '25.3',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Area title').first,
        'ROADS',
      );
      await tester.tap(find.text('Apply row'));
      await tester.pumpAndSettle();
      expect(find.text('25.3%'), findsOneWidget);
      expect(find.textContaining('71,670'), findsWidgets);
    },
  );

  testWidgets('sample schedule fills the page with editable rows and totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: SchemeScanScreen(tab: true)),
    );
    await tester.tap(find.text('Sample schedule'));
    await tester.pumpAndSettle();
    expect(find.text('PARK & GREEN BELT'), findsOneWidget);
    expect(find.text('SOLID WASTE MANAGEMENT & DISPOSAL'), findsOneWidget);
    expect(
      find.text('62.71%'),
      findsOneWidget,
    ); // calculated: area / total area
    // Tick the road row: its K-M-S shows in the selected-area table.
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pumpAndSettle();
    expect(find.text('71,662.25'), findsWidgets);
    // Loading it again over existing rows asks first.
    await tester.tap(find.text('Sample schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Replace the rows with the sample?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'the scanned Total Area row is 100% and other rows are shares of it, even beside a larger register total',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SchemeScanScreen(
            approved: ApprovedLandEntry(
              name: 'Al khair',
              totalArea: '98K-0M-0S',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sample schedule'));
      await tester.pumpAndSettle();
      expect(find.text('100.00%'), findsOneWidget);
      expect(
        find.text('53.06%'),
        findsNothing,
      ); // 52K as a share of the register's 98K
      expect(
        find.text('25.31%'),
        findsOneWidget,
      ); // road area / scanned total area
      // A row flagged for review still shows its calculated square feet and %.
      expect(find.text('19,813.75 sq ft'), findsOneWidget);
      expect(find.text('7.00%'), findsOneWidget);
    },
  );

  testWidgets(
    'a row can be made the Total Area, which moves it to row 1 as the 100% base',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: SchemeScanScreen(tab: true)),
      );
      await tester.tap(find.text('Sample schedule'));
      await tester.pumpAndSettle();
      // Row 2 (Residential Area) becomes the total.
      await tester.tap(find.byTooltip('Row actions').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use as Total Area (row 1)'));
      await tester.pumpAndSettle();
      final firstRow = find.text('RESIDENTIAL AREA');
      final oldTotal = find.text('TOTAL AREA');
      expect(
        tester.getTopLeft(firstRow).dy,
        lessThan(tester.getTopLeft(oldTotal).dy),
      );
      expect(find.text('100.00%'), findsOneWidget);
    },
  );

  testWidgets(
    'a schedule can be marked reviewed only when nothing is left to check',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: SchemeScanScreen(tab: true)),
      );
      await tester.tap(find.text('Sample schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mark Schedule Reviewed'));
      await tester.tap(find.text('Mark Schedule Reviewed'));
      await tester.pumpAndSettle();
      // No scheme name yet, so it says what is missing.
      expect(
        find.text('The schedule is not ready to mark as reviewed'),
        findsOneWidget,
      );
      expect(find.textContaining('Enter the scheme name'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Scheme name'),
        'Test colony',
      );
      await tester.tap(find.text('Mark Schedule Reviewed'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule reviewed'), findsOneWidget);
    },
  );
}
