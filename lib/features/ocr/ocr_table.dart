import '../schemes/logic/scheme.dart';
import '../schemes/logic/scheme_scan.dart';
import 'ocr_models.dart';

/// Feeds any engine's output to the shared table reconstruction (SchemeScan.read).
///
/// Engines that return whole text regions (a line, or several cells in one box) are split at
/// spaces, and the box width is shared between the pieces by character count. Nothing is
/// invented: a region without a width stays one piece at its centre.
List<TableWord> tableWordsFrom(Iterable<OcrWord> words) {
  final result = <TableWord>[];
  for (final word in words) {
    final pieces = word.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((piece) => piece.isNotEmpty)
        .toList();
    if (pieces.isEmpty) continue;
    final width = word.width;
    if (pieces.length == 1 || width == null || width <= 0) {
      result.add((
        text: pieces.join(' '),
        x: word.x,
        y: word.y,
        height: word.height,
      ));
      continue;
    }
    final characters =
        pieces.fold<int>(0, (sum, piece) => sum + piece.length) +
        pieces.length -
        1;
    var cursor = word.x - width / 2;
    for (final piece in pieces) {
      final share = width * piece.length / characters;
      result.add((
        text: piece,
        x: cursor + share / 2,
        y: word.y,
        height: word.height,
      ));
      cursor += share + width / characters;
    }
  }
  return result;
}

/// Rows reconstructed from one engine's run. Values the engine did not read stay empty.
List<SchemeRow> rowsFromRun(OcrRun run) =>
    run.failed ? const [] : SchemeScan.read(tableWordsFrom(run.words));
