import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../schemes/logic/scheme.dart';
import '../ocr_comparison.dart';
import '../ocr_models.dart';
import '../ocr_table.dart';

/// What the person chose on the compare screen.
class OcrCompareResult {
  const OcrCompareResult({
    required this.rows,
    required this.sources,
    required this.runs,
    this.baseEngineId,
  });
  final List<SchemeRow> rows;

  /// `rowNumber.field -> engine id` (or `manual`).
  final Map<String, String> sources;
  final List<OcrRun> runs;
  final String? baseEngineId;
}

/// The same crop read by several engines, side by side. Nothing is chosen automatically: a
/// person picks a whole result, or takes single cells from different engines, and can retype any cell.
class OcrCompareScreen extends StatefulWidget {
  const OcrCompareScreen({
    super.key,
    required this.runs,
    required this.cropBytes,
  });
  final List<OcrRun> runs;
  final Uint8List? cropBytes;

  @override
  State<OcrCompareScreen> createState() => _OcrCompareScreenState();
}

class _OcrCompareScreenState extends State<OcrCompareScreen> {
  late final Map<String, List<SchemeRow>> _rows = {
    for (final run in widget.runs) run.engineId: rowsFromRun(run),
  };
  CombinedTable? _working;
  String? _base;
  List<ExpectedRow>? _expected;

  OcrRun _run(String id) => widget.runs.firstWhere((run) => run.engineId == id);

  void _useResult(OcrRun run) => setState(() {
    _base = run.engineId;
    _working = CombinedTable.from(_rows[run.engineId]!, run.engineId);
  });

  void _takeCell(
    int rowIndex,
    ResultField field,
    SchemeRow from,
    String engineId,
  ) {
    if (_working == null) {
      _toast(
        'Choose "Use this result" for one engine first, then take cells from the others.',
      );
      return;
    }
    if (rowIndex >= _working!.rows.length) {
      _toast('The working table has no row ${rowIndex + 1}.');
      return;
    }
    setState(() => _working!.takeCell(rowIndex, field, from, engineId));
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _editCell(int rowIndex, ResultField field) async {
    final row = _working!.rows[rowIndex];
    final controller = TextEditingController(text: field.valueOf(row.row));
    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Row ${rowIndex + 1}: ${field.label}'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() => _working!.editCell(rowIndex, field, value));
    }
  }

  Future<void> _testingMode() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Testing mode'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type the verified table, one row per line: description, K, M, S, square feet. '
                'Leave a value out if the sheet has none.',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 9,
                decoration: const InputDecoration(
                  hintText: 'TOTAL AREA, 52, 0, 0, 283140',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text('Score engines'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && text.trim().isNotEmpty && mounted) {
      setState(() => _expected = ExpectedRow.parse(text));
    }
  }

  Widget _score() {
    final expected = _expected!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Testing mode: ${expected.length} verified rows',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Engine')),
                  DataColumn(label: Text('Rows recognised')),
                  DataColumn(label: Text('Cells correct')),
                  DataColumn(label: Text('In wrong column')),
                  DataColumn(label: Text('Missing')),
                  DataColumn(label: Text('Incorrect')),
                  DataColumn(label: Text('Extra rows')),
                  DataColumn(label: Text('Time')),
                ],
                rows: [
                  for (final run in widget.runs)
                    () {
                      final score = scoreRows(expected, _rows[run.engineId]!);
                      return DataRow(
                        cells: [
                          DataCell(Text(run.engineName)),
                          DataCell(
                            Text(
                              '${score.rowsRecognised}/${score.expectedRows}',
                            ),
                          ),
                          DataCell(
                            Text(
                              '${score.cellsCorrect}/${score.expectedCells}',
                            ),
                          ),
                          DataCell(Text('${score.cellsInWrongColumn}')),
                          DataCell(Text('${score.cellsMissing}')),
                          DataCell(Text('${score.cellsIncorrect}')),
                          DataCell(Text('${score.extraRows}')),
                          DataCell(Text('${run.duration.inMilliseconds} ms')),
                        ],
                      );
                    }(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runHeader(OcrRun run) {
    final confidences = [for (final word in run.words) ?word.confidence];
    final confidence = confidences.isEmpty
        ? 'No confidence reported by this engine'
        : 'Mean word confidence ${(confidences.reduce((a, b) => a + b) / confidences.length * 100).toStringAsFixed(0)}% (self-reported)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(run.engineName, style: Theme.of(context).textTheme.titleMedium),
        Text(run.engineVersion, style: Theme.of(context).textTheme.bodySmall),
        Text(
          '${run.online ? 'Online' : 'Offline'} · ${run.duration.inMilliseconds} ms · ${run.words.length} words',
        ),
        Text(confidence, style: Theme.of(context).textTheme.bodySmall),
        if (run.failed)
          Text(
            'Failed: ${run.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final warning in run.warnings)
          Text(warning, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  List<String> _warnings(SchemeRow row) => [
    if (row.kanal.trim().isEmpty &&
        row.marla.trim().isEmpty &&
        row.sarsai.trim().isEmpty)
      'K/M/S unreadable',
    if (row.suggestion.isNotEmpty) 'sq ft suggests ${row.suggestion}',
    if (row.sftConflict) 'sq ft and K/M/S disagree',
    if (row.needsReview) 'needs review',
    if (row.classification == AreaClass.review &&
        row.description.trim().isNotEmpty)
      'mixed or unknown use',
  ];

  Widget _runColumn(OcrRun run) {
    final rows = _rows[run.engineId]!;
    final raw = run.rawText.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _runHeader(run),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: run.failed ? null : () => _useResult(run),
          child: Text(
            _base == run.engineId ? 'In the working table' : 'Use this result',
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty && !run.failed)
          const Text('No table rows could be reconstructed from this result.'),
        for (final (index, row) in rows.indexed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${row.description.isEmpty ? '(no description)' : row.description}',
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final field in ResultField.values.skip(1))
                        ActionChip(
                          label: Text(
                            '${field.label}: ${field.valueOf(row).isEmpty ? '—' : field.valueOf(row)}',
                          ),
                          tooltip: 'Take this cell into the working table',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _takeCell(index, field, row, run.engineId),
                        ),
                    ],
                  ),
                  for (final warning in _warnings(row))
                    Text(
                      '⚠ $warning',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ExpansionTile(
          title: const Text('Raw recognised text'),
          children: [
            SelectableText(
              raw.isEmpty
                  ? run.words.map((word) => word.text).join(' ')
                  : (raw.length > 4000 ? '${raw.substring(0, 4000)}…' : raw),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _workingTable() {
    final working = _working;
    if (working == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Working table: choose "Use this result" for one engine, then take or retype cells.',
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Working table (started from ${_run(_base!).engineName})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Text(
              'Under each cell: the engine it came from. Tap a cell to retype it.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('#')),
                  for (final field in ResultField.values)
                    DataColumn(label: Text(field.label)),
                ],
                rows: [
                  for (final (index, row) in working.rows.indexed)
                    DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        for (final field in ResultField.values)
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  field.valueOf(row.row).isEmpty
                                      ? '—'
                                      : field.valueOf(row.row),
                                ),
                                Text(
                                  row.source[field] == manualSource
                                      ? 'typed'
                                      : _run(row.source[field]!).engineName,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                            onTap: () => _editCell(index, field),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                OcrCompareResult(
                  rows: working.toRows(),
                  sources: working.sources(),
                  runs: widget.runs,
                  baseEngineId: _base,
                ),
              ),
              icon: const Icon(Icons.check),
              label: const Text('Use the working table on the Scan page'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final runs = widget.runs;
    final header = <Widget>[
      if (widget.cropBytes != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(height: 70, child: Image.memory(widget.cropBytes!)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Every engine read this same crop. No result is ranked automatically: self-reported confidence is shown '
                  'for information only. Rows are matched by position.',
                ),
              ),
            ],
          ),
        ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _testingMode,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Testing mode'),
          ),
        ],
      ),
      if (_expected != null) _score(),
    ];
    if (runs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compare OCR results')),
        body: const Center(child: Text('Run at least one engine first.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Compare OCR results')),
      body: wide
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...header,
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final run in runs)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _runColumn(run),
                        ),
                      ),
                  ],
                ),
                _workingTable(),
              ],
            )
          : DefaultTabController(
              length: runs.length + 1,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: [
                      for (final run in runs) Tab(text: run.engineName),
                      const Tab(text: 'Working table'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final run in runs)
                          ListView(
                            padding: const EdgeInsets.all(12),
                            children: [...header, _runColumn(run)],
                          ),
                        ListView(
                          padding: const EdgeInsets.all(12),
                          children: [_workingTable()],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
