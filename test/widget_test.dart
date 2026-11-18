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
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
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

    // Verify Functional OCR Scanner interface
    expect(find.text('OCR & Document Scanner'), findsOneWidget);
    expect(find.text('Sample Plan'), findsOneWidget);
    expect(find.text('Load Scheme Sample'), findsOneWidget);
    expect(find.text('Extract Measurements'), findsOneWidget);

    // Tap 'Load Scheme Sample'
    await tester.tap(find.text('Load Scheme Sample'));
    await tester.pumpAndSettle();

    // Verify Mandatory Review section appears with parsed entries
    expect(find.text('Mandatory Review & Correction'), findsOneWidget);
    expect(find.text('Send to Land Calculator'), findsOneWidget);
  });
}
