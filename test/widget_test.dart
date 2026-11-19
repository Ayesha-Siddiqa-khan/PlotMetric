import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/app.dart';

void main() {
  testWidgets('PlotMetricApp launches directly into Land Calculator', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PlotMetricApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title, Land Calculator tab and Conversion reference
    expect(find.text('PlotMetric'), findsWidgets);
    expect(find.text('Land Calculator'), findsOneWidget);
    expect(
      find.text('1 Kanal = 20 Marla · 1 Marla = 9 Sarsai · 1 Marla = 272.25 sq ft'),
      findsOneWidget,
    );

    // Verify single continuous worksheet buttons
    expect(find.text('+ Add'), findsOneWidget);
    expect(find.text('− Deduct'), findsOneWidget);

    // Verify footer actions
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Copy Summary'), findsOneWidget);

    // Verify navigation tabs
    expect(find.text('Land'), findsWidgets);
    expect(find.text('Dimensions'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    final purpose = find.byWidgetPredicate(
      (widget) => widget is EditableText && widget.controller.text == 'Nil',
    );
    expect(purpose, findsOneWidget);
    expect(find.text('Roads'), findsNothing);
    await tester.tap(purpose);
    await tester.pumpAndSettle();
    expect(find.text('Roads'), findsOneWidget);
  });

  testWidgets('Tapping Settings tab opens Settings & Data Management', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PlotMetricApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Settings tab
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Verify Settings screen elements
    expect(find.text('Settings & Data Management'), findsOneWidget);
    expect(find.text('Database Backup & Restore'), findsOneWidget);
    expect(find.text('Backup to JSON'), findsOneWidget);
    expect(find.text('Restore from JSON'), findsOneWidget);
    expect(find.text('Export All Records'), findsOneWidget);
  });

  testWidgets('Tapping Dimensions tab opens Plot Dimensions & Converter', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PlotMetricApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Dimensions tab
    await tester.tap(find.byIcon(Icons.architecture_outlined));
    await tester.pumpAndSettle();

    // Verify Dimensions screen elements
    expect(find.text('Plot Dimensions & Converter'), findsOneWidget);
    expect(find.text('Length × Width (Ft/In)'), findsOneWidget);
    expect(find.text('Direct Sq Ft to Marla'), findsOneWidget);
    expect(find.text('Add to Land Worksheet'), findsOneWidget);
  });

  testWidgets('Tapping Calculator tab switches screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PlotMetricApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Calculator tab
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();

    // Verify Calculator header and AC button
    expect(find.text('Everyday Calculator'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('±'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Settings & Data Management'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Everyday Calculator'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Land Calculator'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Land Calculator'), findsOneWidget);
  });

  testWidgets('Tapping Scan tab opens functional OCR & Document Scanner', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PlotMetricApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Scan tab
    await tester.tap(find.byIcon(Icons.document_scanner_outlined));
    await tester.pumpAndSettle();

    // The Scan tab is a single page: scan, review, save and export.
    expect(find.text('Scan area schedule'), findsOneWidget);
    expect(find.text('Choose image'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Demo Data'), findsNothing);
    expect(find.text('Sample schedule'), findsOneWidget);
    expect(find.text('Scheme name'), findsOneWidget);
  });
}
