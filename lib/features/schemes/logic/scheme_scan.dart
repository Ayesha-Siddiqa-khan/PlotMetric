import 'dart:math' as math;

import '../../land/logic/land_math.dart';
import 'scheme.dart';

typedef TableWord = ({String text, double x, double y, double height});

class SchemeScan {
  static List<SchemeRow> selectedRows(Iterable<SchemeRow> rows, Set<int> selected) => [
    for (final row in rows)
      if (selected.contains(row.id) && row.classification != AreaClass.subtotal)
        // Ticking a row is the user's confirmation; rows without a usable area stay pending.
        SchemeRow.fromJson(row.toJson())
          ..classification = row.classification == AreaClass.gross ? AreaClass.gross : AreaClass.transfer
          ..needsReview = row.area == null,
  ];

  static List<SchemeRow> read(Iterable<TableWord> words) {
    final sorted = words.toList()..sort((a, b) => a.y.compareTo(b.y));
    final lines = <List<TableWord>>[];
    for (final word in sorted) {
      if (lines.isNotEmpty &&
          (word.y - lines.last.map((w) => w.y).reduce((a, b) => a + b) / lines.last.length).abs() <=
              math.min(word.height, lines.last.first.height) * 0.95) {
        lines.last.add(word);
      } else {
        lines.add([word]);
      }
    }
    for (final line in lines) {
      line.sort((a, b) => a.x.compareTo(b.x));
    }

    bool isHeader(List<TableWord> line) {
      final columns = line.map((word) => _column(word.text)).toSet();
      return columns.contains('description') &&
          columns.intersection({'sft', 'k', 'm', 'ms', 'kms'}).isNotEmpty;
    }

    var headerIndex = lines.indexWhere(isHeader);
    if (headerIndex < 0) {
      // On a tilted photo the header cells can fall on two neighbouring lines.
      for (var i = 0; i + 1 < lines.length; i++) {
        final near = (lines[i + 1].first.y - lines[i].first.y).abs() <=
            math.max(lines[i].first.height, lines[i + 1].first.height) * 1.6;
        final merged = [...lines[i], ...lines[i + 1]]..sort((a, b) => a.x.compareTo(b.x));
        if (near && isHeader(merged)) {
          lines.replaceRange(i, i + 2, [merged]);
          headerIndex = i;
          break;
        }
      }
    }
    if (headerIndex < 0) {
      return [
        for (final (index, line) in lines.indexed)
          SchemeRow(
            index + 1,
            description: line.map((word) => word.text).join(' '),
            source: line.map((word) => word.text).join(' '),
            needsReview: true,
          ),
      ];
    }
    final headers = <String, double>{};
    for (final word in lines[headerIndex]) {
      if (_column(word.text) case final key?) headers[key] = word.x;
    }
    _inferMissingAreaColumns(headers, lines.skip(headerIndex + 1).expand((line) => line));
    _inferSquareFeetColumn(headers, lines.skip(headerIndex + 1).expand((line) => line));
    final descriptionCenter = headers['description']!;
    final numeric =
        headers.entries
            .where(
              (entry) =>
                  entry.key != 'description' && entry.value > descriptionCenter,
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    if (numeric.isEmpty) {
      return [
        for (final (index, line) in lines.skip(headerIndex + 1).indexed)
          SchemeRow(
            index + 1,
            description: line.map((word) => word.text).join(' '),
            source: line.map((word) => word.text).join(' '),
            needsReview: true,
          ),
      ];
    }
    final firstNumeric = numeric.first.value;
    final descriptionEnd = numeric.length < 2
        ? (headers['description']! + firstNumeric) / 2
        : firstNumeric - (numeric[1].value - firstNumeric) / 2;
    final numberEdge = headers['number'] == null
        ? descriptionCenter - (firstNumeric - descriptionCenter) * 0.35
        : (headers['number']! + descriptionCenter) / 2;
    // Without a readable % header, values to the right of the M/S column belong to the % column.
    final msColumn = headers['ms'], kanalColumn = headers['k'];
    final percentEdge = !headers.containsKey('percent') && msColumn != null && kanalColumn != null
        ? msColumn + (msColumn - kanalColumn) * 0.62
        : null;
    bool isNumber(TableWord word) =>
        word.x < numberEdge && RegExp(r'^\d{1,2}[.)]?$').hasMatch(word.text);
    var body = lines.skip(headerIndex + 1).toList();
    final anchors = <TableWord>[];
    for (final word in body.expand((line) => line).where(isNumber)) {
      final number = int.parse(word.text.replaceAll(RegExp(r'\D'), ''));
      if (number == 0) continue;
      final previous = anchors.lastOrNull;
      if (previous == null ||
          (word.y - previous.y > word.height &&
              number >
                  int.parse(previous.text.replaceAll(RegExp(r'\D'), '')))) {
        anchors.add(word);
      }
    }
    // The table ends one row after its last serial number. Text further down (a legend,
    // a title block) is not a row, and must not be appended to the last one.
    if (anchors.length >= 3) {
      final gaps = [for (var i = 1; i < anchors.length; i++) anchors[i].y - anchors[i - 1].y]..sort();
      final tableEnd = anchors.last.y + gaps[gaps.length ~/ 2] * 1.15;
      body = [
        for (final line in body)
          if (line.map((word) => word.y).reduce((a, b) => a + b) / line.length <= tableEnd) line,
      ];
    }
    // Serial cells identify the logical rows even when their descriptions wrap.
    final groups = anchors.length < 2
        ? [for (final line in body) [line]]
        : List.generate(anchors.length, (_) => <List<TableWord>>[]);
    if (anchors.length >= 2) {
      for (final line in body) {
        final center =
            line.map((word) => word.y).reduce((a, b) => a + b) / line.length;
        var index = 0;
        while (index + 1 < anchors.length &&
            center >= (anchors[index].y + anchors[index + 1].y) / 2) {
          index++;
        }
        groups[index].add(line);
      }
    }
    // A damaged serial cell can leave two rows in one group: each line that carries
    // its own values starts a new row, and wrapped text joins the nearest one.
    bool hasValues(List<TableWord> line) => line.any(
      (word) =>
          word.x >= descriptionEnd &&
          RegExp(r'\d').hasMatch(word.text) &&
          !isNumber(word),
    );
    double centerOf(List<TableWord> line) =>
        line.map((word) => word.y).reduce((a, b) => a + b) / line.length;
    final logicalRows = <List<TableWord>>[];
    for (final group in groups) {
      final valueLines = group.where(hasValues).toList();
      if (valueLines.length < 2) {
        logicalRows.add([for (final line in group) ...line]);
        continue;
      }
      final parts = [for (final _ in valueLines) <List<TableWord>>[]];
      for (final line in group) {
        var best = 0;
        for (var i = 1; i < valueLines.length; i++) {
          if ((centerOf(line) - centerOf(valueLines[i])).abs() <
              (centerOf(line) - centerOf(valueLines[best])).abs()) {
            best = i;
          }
        }
        parts[best].add(line);
      }
      logicalRows.addAll([for (final part in parts) [for (final line in part) ...line]]);
    }
    // A "Total area of scheme" line is often printed above the table; keep it as a candidate.
    List<TableWord>? aboveTable;
    for (final line in lines.take(headerIndex)) {
      final text = fixWords(
        line.where((word) => RegExp(r'[A-Za-z]{2,}').hasMatch(word.text)).map((word) => word.text).join(' '),
      );
      final numbers = line.where((word) => RegExp(r'^\d').hasMatch(word.text) && word.x >= descriptionCenter);
      if (SchemeRow.classify(text) == AreaClass.gross && numbers.length >= 2) aboveTable = line;
    }
    if (aboveTable != null) logicalRows.insert(0, aboveTable);
    SchemeRow? aboveRow;
    final rows = <SchemeRow>[];
    for (final line in logicalRows) {
      final values = <String, List<String>>{};
      for (final word in line) {
        if (isNumber(word)) {
          values['number'] = [word.text];
          continue;
        }
        // A long label can run past the column edge; words are not numbers.
        // A long number is square feet wherever it sits in its cell (6-digit totals start further left).
        final key = headers.containsKey('sft') && RegExp(r'^\d{4,}[.,\-)]*$').hasMatch(word.text)
            ? 'sft'
            : word.x < descriptionEnd ||
                (RegExp(r'[A-Za-z]{3,}').hasMatch(word.text) && !RegExp(r'^[lIoOsStT|]+$').hasMatch(word.text))
            ? 'description'
            : percentEdge != null && word.x > percentEdge
            ? 'percent'
            : numeric
                  .reduce(
                    (a, b) =>
                        (word.x - a.value).abs() <= (word.x - b.value).abs()
                        ? a
                        : b,
                  )
                  .key;
        values.putIfAbsent(key, () => []).add(word.text);
      }
      // A stray neighbouring value (for example a % read into the Sarsai cell) is not part of the cell.
      for (final key in ['k', 'm', 's']) {
        final cellValues = values[key];
        if (cellValues != null && cellValues.length > 1) {
          values[key] = [cellValues.first];
          if (key == 's' && (values['percent'] ?? []).isEmpty) {
            values['percent'] = cellValues.skip(1).toList();
          }
        }
      }
      var guessed = false;
      String cell(String name) {
        final raw = values[name]?.join(' ') ?? '';
        if (!['k', 'm', 's', 'sft', 'percent'].contains(name)) return _digits(raw);
        final cleaned = _numeric(raw);
        if (cleaned.guessed) guessed = true;
        return cleaned.value;
      }

      final description = fixWords(cell('description').replaceFirst(RegExp(r'^\d{1,2}\s*[.)]\s+'), ''));
      final source = line.map((word) => word.text).join(' ');
      final hasNumbers = numeric.any((column) => cell(column.key).isNotEmpty);
      if (!hasNumbers && !values.containsKey('number') && rows.isNotEmpty) {
        rows.last.description = fixWords('${rows.last.description} $description');
        rows.last.source += '\n$source';
        rows.last.classification = SchemeRow.classify(rows.last.description);
        continue;
      }
      final combined = cell('ms');
      // A combined column can contain labelled units, but unlabeled decimal notation is ambiguous.
      final match = RegExp(
        r'^(\d+(?:\.\d+)?)\s*M\s*[- ]?\s*(\d+(?:\.\d+)?)\s*S$',
        caseSensitive: false,
      ).firstMatch(combined);
      // "15.0" or "19.4½" in an M/S column means 15 Marla 0 Sarsai, or 19 Marla 4½ Sarsai.
      final dotted = RegExp(r'^(\d+)\.(\d+)\s*(½|1/2|\x27|%|"|[tT])?$').firstMatch(combined);
      final combinedKms = cell('kms');
      final kms = RegExp(
        r'^(\d+(?:\.\d+)?)\s*[-–/]\s*(\d+(?:\.\d+)?)\s*[-–/]\s*(\d+(?:\.\d+)?)$',
      ).firstMatch(combinedKms);
      final unambiguousMarla = RegExp(r'^\d+(?:\.0+)?$').hasMatch(combined)
          ? combined
          : '';
      final rawSft = cell('sft');
      final marla = cell('m').isNotEmpty
          ? cell('m')
          : kms?.group(2) ?? match?.group(1) ?? dotted?.group(1) ?? unambiguousMarla;
      final sarsai = cell('s').isNotEmpty
          ? cell('s')
          : kms?.group(3) ??
                match?.group(2) ??
                (dotted == null ? '' : '${dotted.group(2)}${dotted.group(3) == null ? '' : '.5'}');
      final classification = SchemeRow.classify(description);
      final checked = _crossCheck(
        hasSarsaiColumn: numeric.any((column) => ['s', 'ms', 'kms'].contains(column.key)),
        sft: rawSft,
        kanal: kms?.group(1) ?? cell('k'),
        marla: marla,
        sarsai: sarsai,
      );
      if (checked.flag) guessed = true;
      final row = SchemeRow(
        rows.length + 1,
        description: description,
        source: source,
        sft: rawSft,
        kanal: checked.kanal,
        marla: checked.marla,
        sarsai: checked.sarsai,
        suggestion: checked.suggestion,
        // The percentage is calculated from the area and the total area, not read from the photo.
        percent: '',
        classification: classification,
        needsReview:
            guessed ||
            !hasNumbers ||
            description.trim().isEmpty ||
            (combined.isNotEmpty &&
                match == null &&
                dotted == null &&
                unambiguousMarla.isEmpty) ||
            (combinedKms.isNotEmpty && kms == null) ||
            (cell('k').isEmpty && kms == null) ||
            numeric.any(
              (column) =>
                  !['sft', 'percent'].contains(column.key) &&
                  cell(column.key).isEmpty,
            ),
      );
      rows.add(row);
      if (aboveTable != null && identical(line, aboveTable)) aboveRow = row;
    }
    return _totalFirst(rows, aboveRow);
  }

  /// The total area of the whole scheme belongs in row 1; the other rows are its parts.
  /// When the total is written both above and inside the table, the better-read copy is kept.
  static List<SchemeRow> _totalFirst(List<SchemeRow> rows, SchemeRow? above) {
    final totals = rows.where((row) => row.classification == AreaClass.gross).toList();
    var kept = rows;
    if (totals.length > 1 || (above != null && totals.isNotEmpty)) {
      final best = totals.firstWhere(
        (row) => row.area != null && !row.needsReview,
        orElse: () => totals.firstWhere((row) => !identical(row, above), orElse: () => totals.first),
      );
      kept = [for (final row in rows) if (row.classification != AreaClass.gross || identical(row, best)) row];
    }
    final total = kept.where((row) => row.classification == AreaClass.gross).firstOrNull;
    if (total == null) return rows;
    final ordered = [total, ...kept.where((row) => !identical(row, total))];
    return [
      for (final (index, row) in ordered.indexed) SchemeRow.fromJson(row.toJson()..['id'] = index + 1),
    ];
  }

  /// The printed square feet is an independent reading of the same area, so it repairs or
  /// questions the Kanal/Marla/Sarsai cells. Anything filled or doubtful is flagged for review.
  static ({String kanal, String marla, String sarsai, bool flag, String suggestion}) _crossCheck({
    required bool hasSarsaiColumn,
    required String sft,
    required String kanal,
    required String marla,
    required String sarsai,
  }) {
    final printed = sft.trim().isEmpty ? null : SchemeArea.decimal(sft, 4);
    final unchanged = (kanal: kanal, marla: marla, sarsai: sarsai, flag: false, suggestion: '');
    if (printed == null || printed <= 0) return unchanged;
    // Schedules print whole Sarsai, so repair to the nearest whole Sarsai.
    final units = (((printed + SchemeArea.unit ~/ 2) ~/ SchemeArea.unit + 50) ~/ 100) * 100;
    final c = LandMath.centiSarsaiToComposite(units);
    final fromSft = (k: '${c.kanal}', m: '${c.marla}', s: c.sarsaiFormatted);
    bool close(String text, String expected, double tolerance) {
      final value = double.tryParse(text.trim());
      return value != null && (value - double.parse(expected)).abs() <= tolerance;
    }

    // Without a Sarsai column (or with a decimal Marla) the fraction is already inside the Marla
    // cell, so only compare totals; never invent a Sarsai.
    if (!hasSarsaiColumn || marla.contains('.')) {
      if (kanal.trim().isEmpty && marla.trim().isEmpty) {
        return (kanal: kanal, marla: marla, sarsai: sarsai, flag: true, suggestion: '${fromSft.k}K-${fromSft.m}M');
      }
      final read = SchemeArea.land(kanal.trim().isEmpty ? '0' : kanal, marla.trim().isEmpty ? '0' : marla, '0');
      final off = read == null || (read - printed).abs() > 272 * 10000;
      return off ? (kanal: kanal, marla: marla, sarsai: sarsai, flag: true, suggestion: '') : unchanged;
    }
    final missing = [kanal, marla, sarsai].where((value) => value.trim().isEmpty).length;
    if (missing == 3) {
      return (kanal: kanal, marla: marla, sarsai: sarsai, flag: true, suggestion: '${fromSft.k}K-${fromSft.m}M-${fromSft.s}S');
    }
    if (missing > 0) {
      // Fill a gap only when what was read agrees with the square feet.
      final agrees = (kanal.trim().isEmpty || close(kanal, fromSft.k, 0)) &&
          (marla.trim().isEmpty || close(marla, fromSft.m, 1)) &&
          (sarsai.trim().isEmpty || close(sarsai, fromSft.s, 2));
      // Never write into a cell that was not read: offer the square-feet reading instead.
      return (
        kanal: kanal,
        marla: marla,
        sarsai: sarsai,
        flag: true,
        suggestion: agrees ? '${fromSft.k}K-${fromSft.m}M-${fromSft.s}S' : '',
      );
    }
    final read = SchemeArea.land(kanal, marla, sarsai);
    // Printed square feet are rounded, so allow up to one Marla before questioning the cells.
    if (read == null || (read - printed).abs() > 272 * 10000) {
      return (kanal: kanal, marla: marla, sarsai: sarsai, flag: true, suggestion: '');
    }
    return unchanged;
  }

  static const _vocabulary = [
    'TOTAL', 'SCHEME', 'RESIDENTIAL', 'COMMERCIAL', 'PUBLIC', 'BUILDING',
    'MOSQUE', 'MASJID', 'DISPENSARY', 'SOLID', 'WASTE', 'MANAGEMENT',
    'DISPOSAL', 'SEWERAGE', 'GRAVEYARD', 'GREEN', 'ROAD', 'ROADS', 'PARK',
  ];

  static const _phrases = [
    'TOTAL AREA OF PLOT', 'TOTAL AREA OF ROAD', 'TOTAL AREA OF SCHEME',
    'TOTAL AREA', 'TOTAL ROAD AREA', 'RESIDENTIAL AREA',
    'COMMERCIAL AREA', 'PARK & GREEN BELT', 'PARK AND GREEN BELT',
    'PUBLIC BUILDING', 'SOLID WASTE MANAGEMENT & DISPOSAL',
  ];

  static final _longForm = RegExp(r'PUBLIC|BUILDING|SOLID|WASTE|MANAGEMENT|DISPOSAL|DISPENS|SEWERAGE|GRAVEYARD|BLOCK');

  /// When a description is damaged (stray symbols or digits from a smudge or a small print line
  /// underneath), the key word that can still be read decides what the row is.
  static String? _headingFromKeywords(String text) {
    final words = text.toUpperCase().split(RegExp(r'[^A-Z]+')).where((word) => word.isNotEmpty).toSet();
    bool has(String word) => words.contains(word);
    if (has('SCHEME') || has('COLONY')) return 'TOTAL AREA OF SCHEME';
    if (has('ROAD') || has('ROADS')) return 'TOTAL AREA OF ROAD';
    if (has('PLOT') || has('PLOTS')) return 'TOTAL AREA OF PLOT';
    if ((has('MASJID') || has('MOSQUE')) && has('COMMERCIAL')) return 'MASJID COMMERCIAL';
    if (has('MASJID') || has('MOSQUE')) return 'MASJID';
    if (has('COMMERCIAL')) return 'COMMERCIAL';
    if (has('PARK')) return has('GREEN') || has('BELT') ? 'PARK & GREEN BELT' : 'PARK';
    if (has('RESIDENTIAL')) return 'RESIDENTIAL AREA';
    return null;
  }

  /// A description whose letters are within a quarter of a known heading is that heading.
  static String fixWords(String text) {
    final fixed = _fixTokens(text);
    final damaged = RegExp(r'[^A-Za-z\s&().,\-]').hasMatch(fixed) || RegExp(r'\d').hasMatch(fixed);
    if (damaged && !_longForm.hasMatch(fixed.toUpperCase())) {
      final heading = _headingFromKeywords(fixed);
      if (heading != null) return heading;
    }
    final letters = fixed.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.length < 8) return fixed;
    String? best;
    var bestDistance = 1 << 30;
    for (final phrase in _phrases) {
      final target = phrase.replaceAll(RegExp(r'[^A-Z]'), '');
      final distance = _distance(letters, target);
      final keyWord = phrase.split(' ').last;
      // A heading whose last word ("ROAD", "PLOT", "SCHEME") survived can be more badly damaged.
      final allowance = const {'ROAD', 'PLOT', 'SCHEME'}.contains(keyWord) && letters.contains(keyWord) ? 0.42 : 0.25;
      if (distance <= target.length * allowance && distance < bestDistance) {
        best = phrase;
        bestDistance = distance;
      }
    }
    return best ?? fixed;
  }

  /// Repairs words the OCR damaged ("OMMERCIAL", "BUI-DING", "SOLIG").
  static String _fixTokens(String text) => text.split(RegExp(r'\s+')).map((token) {
    // A word with stray symbols ("COUME├åCAL") is matched on its letters, more loosely.
    final smudged = !RegExp(r'^[A-Za-z\-]+$').hasMatch(token) &&
        !RegExp(r'[\d()&]').hasMatch(token) &&
        token.replaceAll(RegExp(r'[^A-Za-z]'), '').length >= 5;
    if (!smudged && !RegExp(r'^[A-Za-z\-]+$').hasMatch(token)) return token;
    final word = token.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    // Short key words (PARK, ROAD, PLOT) are common enough to fix a single wrong letter.
    if (word.length == 4 && ['PARK', 'ROAD', 'PLOT'].every((key) => key != word)) {
      for (final key in ['PARK', 'ROAD', 'PLOT']) {
        if (_distance(word, key) == 1) return key;
      }
    }
    if (word.length < 5) return token;
    final limit = smudged ? (word.length * 0.4).floor() : (word.length >= 8 ? 2 : 1);
    String? best;
    var bestDistance = limit + 1;
    for (final candidate in _vocabulary) {
      final distance = _distance(word, candidate);
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best ?? token;
  }).join(' ');

  /// Repairs digits the OCR confused with letters. Anything beyond a plain zero is a guess.
  static ({String value, bool guessed}) _numeric(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (value: '', guessed: false);
    var value = trimmed.replaceAll(RegExp(r'(?<=\d)[oO](?=\d|$)|^[oO](?=\d|$|\.)'), '0');
    value = value == 'o' || value == 'O' ? '0' : value;
    if (RegExp(r'^\d+(?:\.\d+)?%?$').hasMatch(value)) {
      return (value: value.endsWith('%') ? value.substring(0, value.length - 1) : value, guessed: false);
    }
    // Several tokens, a trailing dot or a stray symbol: keep only the number-like part.
    var guessed = false;
    final mapped = value
        .replaceAll(RegExp(r'[{\[|lItT]'), '1')
        .replaceAll(RegExp(r'[Ss]'), '5')
        .replaceAll(RegExp(r'[oO]'), '0');
    if (mapped != value) guessed = true;
    // Left-over letters mean this was not a number at all (for example "as"): read nothing.
    if (RegExp(r'[A-Za-z]').hasMatch(mapped)) return (value: '', guessed: true);
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(mapped);
    if (match == null) return (value: '', guessed: false);
    if (mapped.replaceAll(RegExp(r'[.\-—\s]+$'), '') != match.group(0)) guessed = true;
    return (value: match.group(0)!, guessed: guessed);
  }

  // OCR often reads a printed zero as the letter O.
  static String _digits(String text) =>
      RegExp(r'^[oO]$').hasMatch(text.trim()) ? '0' : text;

  // Coloured or boxed header cells are often missed. When only the Kanal header
  // or only some of the K/M/S headers were read, take the columns from the numbers beneath them.
  static void _inferMissingAreaColumns(
    Map<String, double> headers,
    Iterable<TableWord> body,
  ) {
    final kanal = headers['k'];
    if (kanal == null ||
        ['ms', 'kms'].any(headers.containsKey) ||
        (headers.containsKey('m') && headers.containsKey('s')) ||
        // A K / M / % table has no Sarsai column to infer.
        (headers.containsKey('m') && headers.containsKey('percent'))) {
      return;
    }
    final numeric = RegExp(r'^[\dOo]+(?:\.\d+)?%?$');
    final candidates = body.where((word) => numeric.hasMatch(word.text)).toList();
    if (candidates.length < 3) return;
    final heights = candidates.map((word) => word.height).toList()..sort();
    final words = candidates.where((word) => word.x > kanal - heights[heights.length ~/ 2] * 1.2).toList()
      ..sort((a, b) => a.x.compareTo(b.x));
    if (words.length < 3) return;
    final gap = heights[heights.length ~/ 2] * 1.8;
    final columns = <List<double>>[];
    final texts = <List<String>>[];
    for (final word in words) {
      if (columns.isNotEmpty && word.x - columns.last.last <= gap) {
        columns.last.add(word.x);
        texts.last.add(word.text);
      } else {
        columns.add([word.x]);
        texts.add([word.text]);
      }
    }
    double mean(List<double> values) => values.reduce((a, b) => a + b) / values.length;
    if (columns.length < 3) return;
    headers['k'] = mean(columns[0]);
    headers['m'] = mean(columns[1]);
    // Sarsai is a single digit; a third column holding larger numbers is the %.
    final thirdIsPercent = columns.length == 3 &&
        texts[2].any((text) => (double.tryParse(text.replaceAll(RegExp(r'[oO]'), '0')) ?? 0) >= 9);
    if (thirdIsPercent) {
      headers.putIfAbsent('percent', () => mean(columns[2]));
      return;
    }
    headers['s'] = mean(columns[2]);
    if (columns.length > 3) headers.putIfAbsent('percent', () => mean(columns[3]));
  }

  static int _distance(String a, String b) {
    var previous = List.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = [i, ...List.filled(b.length, 0)];
      for (var j = 1; j <= b.length; j++) {
        current[j] = math.min(
          math.min(current[j - 1], previous[j]) + 1,
          previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        );
      }
      previous = current;
    }
    return previous[b.length];
  }

  /// OCR often garbles a long header ("DISCR)PTION"); accept a close match.
  // When the SFT header was missed, the 4+ digit numbers left of the Kanal column mark it.
  static void _inferSquareFeetColumn(Map<String, double> headers, Iterable<TableWord> body) {
    final kanal = headers['k'];
    final description = headers['description'];
    if (headers.containsKey('sft') || kanal == null || description == null) return;
    final xs = body
        .where((word) => RegExp(r'^\d{4,}[.,\-]?$').hasMatch(word.text) && word.x > description && word.x < kanal)
        .map((word) => word.x)
        .toList()
      ..sort();
    if (xs.isNotEmpty) headers['sft'] = xs[xs.length ~/ 2];
  }

  static String? _column(String text) {
    final exact = _exactColumn(text);
    if (exact != null) return exact;
    final letters = text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (letters.length >= 7 &&
        ['description', 'discription', 'particulars']
            .any((word) => _distance(letters, word) <= 2)) {
      return 'description';
    }
    return null;
  }

  static String? _exactColumn(String text) =>
      switch (text.toLowerCase().replaceAll(RegExp(r'[^a-z%]'), '')) {
        'description' ||
        'discription' ||
        'des' ||
        'deo' ||
        'dec' ||
        'dcs' ||
        'desc' ||
        'descr' ||
        'particulars' => 'description',
        'sft' || 'sqft' || 'sf' || 'ft' => 'sft',
        'k' || 'kanal' => 'k',
        'm' || 'marla' => 'm',
        's' || 'sarsai' => 's',
        'ms' || 'mis' || 'mls' => 'ms',
        'kms' => 'kms',
        '%' || 'percent' => 'percent',
        'sno' || 'sr' => 'number',
        _ => null,
      };
}
