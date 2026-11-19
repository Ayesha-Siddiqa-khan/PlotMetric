import '../../../core/utils/number_formatters.dart';
import 'scheme.dart';

class SchemeRegisterCsv {
  static List<String> readNames(String csv) {
    final rows = _parse(csv.replaceFirst('\uFEFF', ''));
    if (rows.isEmpty) throw const FormatException('The CSV file is empty.');
    const headers = {
      'nameofhousingscheme', 'nameofhousescheme', 'housingschemename',
      'housingscheme', 'schemename', 'colonyname', 'colonytitle', 'name',
    };
    var nameColumn = -1;
    var firstDataRow = 0;
    for (final (index, row) in rows.indexed) {
      nameColumn = row.indexWhere((value) =>
          headers.contains(value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')));
      if (nameColumn >= 0) {
        firstDataRow = index + 1;
        break;
      }
    }
    if (nameColumn < 0) {
      if (rows.any((row) => row.length != 1)) {
        throw const FormatException('Use a CSV column named Name of Housing Scheme.');
      }
      nameColumn = 0;
    }
    final found = <String, String>{};
    for (final row in rows.skip(firstDataRow)) {
      if (row.length <= nameColumn) continue;
      final name = row[nameColumn].trim().replaceAll(RegExp(r'\s+'), ' ');
      if (name.isNotEmpty && name.length <= 120) {
        found.putIfAbsent(name.toLowerCase(), () => name);
      }
    }
    if (found.isEmpty) throw const FormatException('No scheme names were found in the CSV.');
    return found.values.toList();
  }

  static String export(Iterable<String> catalog, Iterable<HousingScheme> records) {
    final rows = <List<Object?>>[
      ['S.No.', 'Name of Housing Scheme', 'Owner / Developer', 'Location / Chak',
       'Block / Phase', 'Approval Reference', 'Total Area (K/M/S)', 'Total Area (sq ft)',
       'Transferable (sq ft)', 'Mortgage (sq ft)', 'Verified Transferred (sq ft)', 'Outstanding (sq ft)'],
    ];
    final represented = <String>{};
    final sorted = records.toList()..sort((left, right) =>
      left.name.toLowerCase().compareTo(right.name.toLowerCase()));
    for (final scheme in sorted) {
      represented.add(scheme.name.trim().toLowerCase());
      final totals = scheme.totals;
      rows.add([
        rows.length, scheme.name, scheme.owner, scheme.location, scheme.block, scheme.approval,
        if (totals.gross != null) SchemeArea.composite(totals.gross) else null,
        _squareFeet(totals.gross), _squareFeet(totals.due),
        if (scheme.rows.any((row) => row.mortgageSft.trim().isNotEmpty))
          _squareFeet(totals.mortgage) else null,
        _squareFeet(totals.verified), _squareFeet(totals.remaining),
      ]);
    }
    for (final name in catalog) {
      if (represented.add(name.trim().toLowerCase())) {
        rows.add([rows.length, name, ...List<Object?>.filled(10, null)]);
      }
    }
    return '\uFEFF${rows.map((row) => row.map(_cell).join(',')).join('\r\n')}\r\n';
  }

  static String? _squareFeet(int? amount) => amount == null ? null
      : NumberFormatters.formatSquareFeetFromTenThousandths(amount).replaceAll(',', '');

  static String _cell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^\s*[=+\-@]').hasMatch(text)) text = "'$text";
    return RegExp(r'[,"\r\n]').hasMatch(text) ? '"${text.replaceAll('"', '""')}"' : text;
  }

  static List<List<String>> _parse(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    void fieldEnd() {
      row.add(field.toString());
      field = StringBuffer();
    }
    void rowEnd() {
      fieldEnd();
      if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
      row = [];
    }
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (quoted) {
        if (char != '"') {
          field.write(char);
        } else if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else if (char == '"' && field.isEmpty) {
        quoted = true;
      } else if (char == ',') {
        fieldEnd();
      } else if (char == '\n' || char == '\r') {
        rowEnd();
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      } else {
        field.write(char);
      }
    }
    if (quoted) throw const FormatException('An opening quote in the CSV has no matching closing quote.');
    rowEnd();
    return rows;
  }
}
