import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'scheme.dart';

typedef ReportTable = ({
  String title,
  List<String> headers,
  List<List<Object?>> rows,
});

class SchemeReport {
  SchemeReport(this.scheme);
  final HousingScheme scheme;
  SchemeTotals get totals => scheme.totals;
  bool get draft =>
      !scheme.reviewed ||
      scheme.scheduleIssues.isNotEmpty ||
      scheme.evidence.any((doc) => !totals.isVerified(doc));
  bool get hasMortgage =>
      scheme.rows.any((row) => row.mortgageSft.trim().isNotEmpty);

  List<List<Object?>> get summary => [
    ['Scheme', scheme.name],
    ['Block / phase', scheme.block],
    ['Owner / developer', scheme.owner],
    ['Location', scheme.location],
    ['Municipal recipient', scheme.recipient],
    ['Approval reference', scheme.approval],
    ['Status', draft ? 'Draft' : 'Schedule reviewed'],
    ['Gross area (sq ft)', _sqft(totals.gross)],
    ['Reviewed non-plot area (sq ft)', _sqft(totals.nonPlot)],
    ['Calculated plot area (sq ft)', _sqft(totals.calculatedPlots)],
    ['Owner-plot area from schedule (sq ft)', _sqft(totals.printedPlots)],
    ['Map difference (sq ft)', _sqft(totals.mapDifference)],
    ['Due (sq ft)', _sqft(totals.due), SchemeArea.composite(totals.due)],
    ['Gross less transferable (sq ft)', _sqft(totals.grossLessTransferable)],
    [
      'Verified transferred (sq ft)',
      _sqft(totals.verified),
      SchemeArea.composite(totals.verified),
    ],
    [
      'Outstanding (sq ft)',
      _sqft(totals.remaining),
      SchemeArea.composite(totals.remaining),
    ],
    ['Excess transfer (sq ft)', _sqft(totals.overage)],
    if (hasMortgage) ['Mortgage (sq ft)', _sqft(totals.mortgage)],
  ];

  ReportTable get schedule {
    final columns = scheme.columns
        .where(
          (column) =>
              !scheme.hiddenColumns.contains(column) &&
              (column != ScheduleColumn.mortgage || hasMortgage),
        )
        .toList();
    return (
      title: 'Area Schedule',
      headers: [
        for (final column in columns)
          scheme.columnNames[column] ?? column.label,
      ],
      rows: [
        for (final row in scheme.rows)
          [
            for (final column in columns)
              switch (column) {
                ScheduleColumn.description => row.description,
                ScheduleColumn.type =>
                  row.ready ? row.classification.label : 'Needs review',
                ScheduleColumn.kanal => num.tryParse(row.kanal) ?? row.kanal,
                ScheduleColumn.marla => num.tryParse(row.marla) ?? row.marla,
                ScheduleColumn.sarsai => num.tryParse(row.sarsai) ?? row.sarsai,
                ScheduleColumn.percent => switch (SchemeArea.percentHundredths(
                  row.needsReview ? null : row.area,
                  totals.gross,
                )) {
                  final hundredths? => hundredths % 100 == 0 ? hundredths ~/ 100 : hundredths / 100,
                  null => null,
                },
                ScheduleColumn.chosen => _sqft(
                  row.needsReview ? null : row.area,
                ),
                ScheduleColumn.mortgage => _sqft(row.mortgage),
              },
          ],
      ],
    );
  }

  ReportTable get balances => (
    title: 'Transfer Reconciliation',
    headers: [
      'Category',
      'Due sq ft',
      'Verified sq ft',
      'Outstanding sq ft',
      'Excess sq ft',
    ],
    rows: [
      for (final row in totals.dueRows)
        [
          row.description,
          _sqft(row.area),
          _sqft(totals.transferred(row)),
          _sqft(totals.outstanding(row)),
          _sqft(totals.excess(row)),
        ],
    ],
  );

  ReportTable get documents => (
    title: 'Transfer Evidence',
    headers: [
      'Document',
      'Reference',
      'Date',
      'Recipient',
      'Document sq ft',
      'Status',
      'Allocation',
      'Allocated sq ft',
    ],
    rows: [
      for (final doc in scheme.evidence)
        if (doc.allocations.isEmpty)
          [..._evidencePrefix(doc), null, null]
        else
          for (final allocation in doc.allocations.entries)
            [
              ..._evidencePrefix(doc),
              scheme.rows
                      .where((row) => row.id == allocation.key)
                      .firstOrNull
                      ?.description ??
                  'Missing row',
              _sqft(SchemeArea.decimal(allocation.value, 4)),
            ],
    ],
  );

  List<Object?> _evidencePrefix(TransferEvidence doc) => [
    doc.type.name,
    doc.reference,
    doc.date,
    doc.recipient,
    _sqft(doc.areaSft.isEmpty ? null : doc.area),
    totals.isVerified(doc) ? 'Verified' : 'Pending',
  ];

  static num? _sqft(int? amount) => amount == null
      ? null
      : amount % 10000 == 0
      ? amount ~/ 10000
      : amount / 10000;

  Uint8List excelBytes() {
    final book = Excel.createExcel();
    book.rename('Sheet1', 'Scheme Report');
    final main = book['Scheme Report'];
    final detail = book['Transfer Evidence'];
    final header = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#173447'),
      fontColorHex: ExcelColor.white,
      textWrapping: TextWrapping.WrapText,
    );
    final bold = CellStyle(bold: true);
    void append(Sheet sheet, List<Object?> values, [CellStyle? style]) {
      final row = sheet.maxRows;
      for (final (index, value) in values.indexed) {
        if (value == null) continue;
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: index, rowIndex: row),
        );
        cell.value = switch (value) {
          int number => IntCellValue(number),
          double number => DoubleCellValue(number),
          _ => TextCellValue(value.toString()),
        };
        if (style != null) cell.cellStyle = style;
      }
    }

    void table(Sheet sheet, ReportTable data) {
      append(sheet, [data.title], bold);
      append(sheet, data.headers, header);
      for (final row in data.rows) {
        append(sheet, row);
      }
    }

    append(main, ['Housing Scheme Report'], header);
    for (final row in summary) {
      append(main, row);
    }
    table(main, schedule);
    table(main, balances);
    if (totals.issues.isNotEmpty) {
      append(main, ['Review items'], bold);
      for (final issue in totals.issues) {
        append(main, [issue]);
      }
    }
    table(detail, documents);
    for (var index = 0; index < main.maxColumns; index++) {
      main.setColumnWidth(index, index == 0 ? 38 : 23);
    }
    for (var index = 0; index < detail.maxColumns; index++) {
      detail.setColumnWidth(index, index == 6 ? 36 : 23);
    }
    final bytes = book.encode();
    if (bytes == null) throw StateError('Could not create the Excel workbook.');
    return Uint8List.fromList(bytes);
  }
}
