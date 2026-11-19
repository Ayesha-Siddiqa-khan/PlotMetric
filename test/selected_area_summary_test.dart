import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotmetric/features/schemes/logic/scheme.dart';
import 'package:plotmetric/features/schemes/presentation/scheme_scan_screen.dart';

void main() {
  testWidgets('already transferred fields accept typing and update the remaining report', (tester) async {
    final k = TextEditingController(), m = TextEditingController(), s = TextEditingController();
    final row = SchemeRow(1, description: 'ROAD', kanal: '13', marla: '3', sarsai: '2',
        classification: AreaClass.transfer);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SelectedAreaSummary(
            rows: [row],
            due: row.area!,
            transferredKanal: k,
            transferredMarla: m,
            transferredSarsai: s,
          ),
        ),
      ),
    ));
    await tester.enterText(find.widgetWithText(TextField, 'Kanal'), '5');
    await tester.pump();
    expect(k.text, '5');
    expect(find.text('8'), findsWidgets); // 13 - 5 kanal remaining
  });
}
