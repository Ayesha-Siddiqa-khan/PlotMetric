import 'dart:convert';
import 'dart:typed_data';

import 'pdf_export_service.dart';
import 'word_exporter.dart';

/// One column of an exported table.
class ExportColumn {
  const ExportColumn(
    this.id,
    this.label, {
    this.weight = 1,
    this.centred = false,
  });
  final String id, label;

  /// Relative width in the PDF.
  final double weight;
  final bool centred;
}

/// A named block of rows (one colony register, or one saved schedule). Each row lists its values
/// in the order of the full column list given to the export dialog.
class ExportGroup {
  const ExportGroup(this.name, this.rows);
  final String name;
  final List<List<String>> rows;
}

/// Builds CSV, Word, PDF and chat text from a table. Nothing here touches storage.
class TableFormats {
  const TableFormats._();

  static String _field(String value) => value.contains(RegExp(r'[",\r\n]'))
      ? '"${value.replaceAll('"', '""')}"'
      : value;

  /// UTF-8 with a byte-order mark so Excel opens it correctly; CRLF line ends.
  static Uint8List csv(
    List<String> headers,
    List<List<String>> rows,
  ) => Uint8List.fromList(
    utf8.encode(
      '\uFEFF${[headers.map(_field).join(','), for (final row in rows) row.map(_field).join(',')].join('\r\n')}\r\n',
    ),
  );

  static Uint8List word({
    required String title,
    String? subtitle,
    String? metadata,
    required List<ExportColumn> columns,
    required List<String> headers,
    required List<List<String>> rows,
  }) => Uint8List.fromList(
    utf8.encode(
      WordExporter.exportTable(
        title: title,
        subtitle: subtitle,
        metadataLine: metadata,
        headers: headers,
        rows: rows,
        centredColumns: [for (final column in columns) column.centred],
      ),
    ),
  );

  static Uint8List pdf({
    required String title,
    String? subtitle,
    required List<ExportColumn> columns,
    required List<String> headers,
    required List<List<String>> rows,
  }) => PdfExportService.generateTablePdf(
    title: title,
    subtitle: subtitle,
    headers: headers,
    rows: rows,
    weights: [for (final column in columns) column.weight],
    centredColumns: [for (final column in columns) column.centred],
  );

  /// A compact message for WhatsApp or any chat: a block per row, only the chosen columns.
  static String chatText({
    required String title,
    String? subtitle,
    required List<ExportColumn> columns,
    required List<ExportGroup> groups,
    required List<int> columnIndexes,
  }) {
    final buffer = StringBuffer('*$title*\n');
    if (subtitle != null && subtitle.isNotEmpty) {
      buffer.writeln(subtitle);
    }
    for (final group in groups) {
      if (groups.length > 1) {
        buffer.writeln('\n*${group.name}*');
      }
      for (final row in group.rows) {
        buffer.writeln();
        for (final (n, index) in columnIndexes.indexed) {
          final value = row[index].trim();
          if (value.isEmpty || value == '-') {
            continue;
          }
          buffer.writeln(
            n == 0 ? '*$value*' : '${columns[index].label}: $value',
          );
        }
      }
    }
    buffer.writeln('\nSent from PlotMetric');
    return buffer.toString();
  }
}
