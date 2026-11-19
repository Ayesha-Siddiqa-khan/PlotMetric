import '../schemes/logic/scheme.dart';
import '../schemes/logic/scheme_scan.dart';

/// The cells a person can compare and combine across engines.
enum ResultField {
  description('Description'),
  kanal('Kanal'),
  marla('Marla'),
  sarsai('Sarsai'),
  sft('Sq ft');

  const ResultField(this.label);
  final String label;

  String valueOf(SchemeRow row) => switch (this) {
    description => row.description,
    kanal => row.kanal,
    marla => row.marla,
    sarsai => row.sarsai,
    sft => row.sft,
  };
}

const manualSource = 'manual';

/// A working table assembled from one or more engines' results. Every cell remembers where it
/// came from, so a corrected table can be audited later.
class CombinedTable {
  CombinedTable._(this.rows);

  /// Starts from one engine's rows ("Use this result").
  factory CombinedTable.from(List<SchemeRow> rows, String engineId) =>
      CombinedTable._([
        for (final row in rows)
          CombinedRow(SchemeRow.fromJson(row.toJson()), {
            for (final field in ResultField.values) field: engineId,
          }),
      ]);

  final List<CombinedRow> rows;

  /// Takes one cell from another engine's result. Nothing else in the row changes.
  void takeCell(
    int rowIndex,
    ResultField field,
    SchemeRow from,
    String engineId,
  ) {
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    final target = rows[rowIndex];
    _set(target.row, field, field.valueOf(from));
    target.source[field] = engineId;
  }

  /// A typed correction.
  void editCell(int rowIndex, ResultField field, String value) {
    final target = rows[rowIndex];
    _set(target.row, field, value);
    target.source[field] = manualSource;
  }

  static void _set(SchemeRow row, ResultField field, String value) {
    switch (field) {
      case ResultField.description:
        row.description = value;
      case ResultField.kanal:
        row.kanal = value;
      case ResultField.marla:
        row.marla = value;
      case ResultField.sarsai:
        row.sarsai = value;
      case ResultField.sft:
        row.sft = value;
    }
  }

  /// Rows ready to import; each keeps the "needs review" mark until a person clears it.
  List<SchemeRow> toRows() => [for (final row in rows) row.row];

  /// `rowNumber.field -> engine id` for the saved provenance.
  Map<String, String> sources() => {
    for (final (index, row) in rows.indexed)
      for (final entry in row.source.entries)
        '${index + 1}.${entry.key.name}': entry.value,
  };
}

class CombinedRow {
  CombinedRow(this.row, this.source);
  final SchemeRow row;
  final Map<ResultField, String> source;
}

/// One row of a hand-verified table, used to score engines against each other.
class ExpectedRow {
  const ExpectedRow(
    this.description, {
    this.kanal = '',
    this.marla = '',
    this.sarsai = '',
    this.sft = '',
  });
  final String description, kanal, marla, sarsai, sft;

  /// Lines of `description, K, M, S, SFT` (commas or tabs; the last columns may be left out).
  static List<ExpectedRow> parse(String text) => [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty)
        () {
          final parts = line
              .split(RegExp(r'[,\t]'))
              .map((part) => part.trim())
              .toList();
          String at(int i) => i < parts.length ? parts[i] : '';
          return ExpectedRow(
            at(0),
            kanal: at(1),
            marla: at(2),
            sarsai: at(3),
            sft: at(4),
          );
        }(),
  ];
}

class BenchmarkScore {
  const BenchmarkScore({
    required this.expectedRows,
    required this.rowsRecognised,
    required this.expectedCells,
    required this.cellsCorrect,
    required this.cellsInWrongColumn,
    required this.cellsMissing,
    required this.cellsIncorrect,
    required this.extraRows,
  });

  final int expectedRows, rowsRecognised;
  final int expectedCells,
      cellsCorrect,
      cellsInWrongColumn,
      cellsMissing,
      cellsIncorrect;
  final int extraRows;
}

/// Scores one engine's rows against a verified table. Numbers are compared as numbers
/// ("09" equals "9"); a number that sits in another column of the same row is counted as a
/// column-placement error rather than as simply wrong.
BenchmarkScore scoreRows(List<ExpectedRow> expected, List<SchemeRow> actual) {
  String key(String text) =>
      SchemeScan.fixWords(text).toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  bool sameNumber(String a, String b) {
    final x = double.tryParse(a.replaceAll(',', '')),
        y = double.tryParse(b.replaceAll(',', ''));
    return x != null && y != null
        ? (x - y).abs() < 0.0001
        : a.trim() == b.trim();
  }

  final used = <int>{};
  var rowsRecognised = 0,
      cells = 0,
      correct = 0,
      wrongColumn = 0,
      missing = 0,
      incorrect = 0;
  for (final row in expected) {
    var match = actual.indexWhere(
      (candidate) =>
          !used.contains(actual.indexOf(candidate)) &&
          key(candidate.description) == key(row.description),
    );
    if (match < 0) {
      final index = expected.indexOf(row);
      if (index < actual.length && !used.contains(index)) match = index;
    }
    final found = match < 0 ? null : actual[match];
    if (found != null) {
      used.add(match);
      if (key(found.description) == key(row.description)) rowsRecognised++;
    }
    final wanted = {
      ResultField.kanal: row.kanal,
      ResultField.marla: row.marla,
      ResultField.sarsai: row.sarsai,
      ResultField.sft: row.sft,
    };
    for (final entry in wanted.entries) {
      if (entry.value.isEmpty) continue;
      cells++;
      final got = found == null ? '' : entry.key.valueOf(found);
      if (got.isEmpty) {
        missing++;
      } else if (sameNumber(got, entry.value)) {
        correct++;
      } else if (found != null &&
          wanted.keys.any(
            (other) =>
                other != entry.key &&
                sameNumber(other.valueOf(found), entry.value),
          )) {
        wrongColumn++;
      } else {
        incorrect++;
      }
    }
  }
  return BenchmarkScore(
    expectedRows: expected.length,
    rowsRecognised: rowsRecognised,
    expectedCells: cells,
    cellsCorrect: correct,
    cellsInWrongColumn: wrongColumn,
    cellsMissing: missing,
    cellsIncorrect: incorrect,
    extraRows: actual.length - used.length,
  );
}
