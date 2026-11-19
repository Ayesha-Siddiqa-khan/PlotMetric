import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic/file_save_helper.dart';
import '../logic/table_formats.dart';

typedef ExportSaver = Future<ExportFileResult> Function(String fileName, Uint8List bytes);

class _Saved {
  const _Saved(this.format, this.result);
  final String format;
  final ExportFileResult result;
}

/// Export a table as PDF, Word, CSV or a WhatsApp message. The person picks the columns; the rows
/// were already chosen on the page. When several groups (for example saved schedules) are exported
/// they can be one combined file or a separate file for each.
class TableExportDialog extends StatefulWidget {
  const TableExportDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.columns,
    required this.groups,
    required this.fileStem,
    this.initialColumnIds,
    this.saver,
    this.share,
    this.open,
    this.sendText,
  });

  final String title;
  final String? subtitle;

  /// Every column that can be exported; each group's rows hold one value per column, in this order.
  final List<ExportColumn> columns;
  final List<ExportGroup> groups;
  final String fileStem;
  final Set<String>? initialColumnIds;

  /// Replace saving, sharing, opening and chat sending (tests use this; the app uses the real ones).
  final ExportSaver? saver;
  final Future<bool> Function(String path, {bool whatsApp})? share;
  final Future<bool> Function(String path)? open;
  final Future<void> Function(String text)? sendText;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<ExportColumn> columns,
    required List<ExportGroup> groups,
    required String fileStem,
    Set<String>? initialColumnIds,
  }) => showDialog<void>(
    context: context,
    builder: (_) => TableExportDialog(
      title: title,
      subtitle: subtitle,
      columns: columns,
      groups: groups,
      fileStem: fileStem,
      initialColumnIds: initialColumnIds,
    ),
  );

  @override
  State<TableExportDialog> createState() => _TableExportDialogState();
}

class _TableExportDialogState extends State<TableExportDialog> {
  late final Set<String> _columns = {...(widget.initialColumnIds ?? widget.columns.map((c) => c.id))};
  bool _separate = false;
  bool _busy = false;
  String? _message;
  final _saved = <_Saved>[];

  int get _rowCount => widget.groups.fold(0, (sum, group) => sum + group.rows.length);

  List<int> get _indexes => [
    for (final (i, column) in widget.columns.indexed)
      if (_columns.contains(column.id)) i,
  ];

  String get _timestamp => DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

  /// The files for one format: a single combined table, or one table per group.
  List<({String name, Uint8List bytes})> _build(String format) {
    final indexes = _indexes;
    final selected = [for (final i in indexes) widget.columns[i]];
    final ext = switch (format) {
      'PDF' => 'pdf',
      'Word' => 'doc',
      _ => 'csv',
    };
    Uint8List make(String title, List<String> headers, List<List<String>> rows, List<ExportColumn> columns) =>
        switch (format) {
          'PDF' => TableFormats.pdf(title: title, subtitle: widget.subtitle, columns: columns, headers: headers, rows: rows),
          'Word' => TableFormats.word(
            title: title,
            subtitle: widget.subtitle,
            metadata: 'Generated ${DateTime.now().toLocal().toString().split('.').first}',
            columns: columns,
            headers: headers,
            rows: rows,
          ),
          _ => TableFormats.csv(headers, rows),
        };

    if (_separate && widget.groups.length > 1) {
      return [
        for (final group in widget.groups)
          (
            name: '${_safe(group.name)}_$_timestamp.$ext',
            bytes: make(
              '${widget.title} - ${group.name}',
              [for (final column in selected) column.label],
              [
                for (final row in group.rows) [for (final i in indexes) row[i]],
              ],
              selected,
            ),
          ),
      ];
    }
    final combined = widget.groups.length > 1;
    final columns = combined ? [const ExportColumn('_group', 'Schedule', weight: 1.6), ...selected] : selected;
    return [
      (
        name: '${_safe(widget.fileStem)}_$_timestamp.$ext',
        bytes: make(
          widget.title,
          [for (final column in columns) column.label],
          [
            for (final group in widget.groups)
              for (final row in group.rows) [if (combined) group.name, for (final i in indexes) row[i]],
          ],
          columns,
        ),
      ),
    ];
  }

  static String _safe(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').replaceAll(RegExp(r'_+'), '_');

  Future<void> _export(String format) async {
    if (_columns.isEmpty) {
      setState(() => _message = 'Choose at least one column.');
      return;
    }
    if (_rowCount == 0) {
      setState(() => _message = 'There is nothing to export.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _saved.clear();
    });
    try {
      final save = widget.saver ?? (name, bytes) => FileSaveHelper.saveBinaryFile(fileName: name, bytes: bytes);
      final failed = <String>[];
      for (final file in _build(format)) {
        final result = await save(file.name, file.bytes);
        if (result.success) {
          _saved.add(_Saved(format, result));
        } else {
          failed.add(result.errorMessage ?? file.name);
        }
      }
      if (mounted) {
        setState(
          () => _message = failed.isEmpty
              ? '${_saved.length == 1 ? '1 file' : '${_saved.length} files'} saved.'
              : 'Could not save: ${failed.join('; ')}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Export failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _whatsApp() async {
    if (_columns.isEmpty) {
      setState(() => _message = 'Choose at least one column.');
      return;
    }
    final text = TableFormats.chatText(
      title: widget.title,
      subtitle: widget.subtitle,
      columns: widget.columns,
      groups: widget.groups,
      columnIndexes: _indexes,
    );
    await (widget.sendText ?? FileSaveHelper.shareViaWhatsApp)(text);
    if (mounted) {
      setState(() => _message = 'WhatsApp message prepared. If WhatsApp did not open, the text is on the clipboard.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.groups.length > 1;
    return AlertDialog(
      scrollable: true,
      title: Text('Export: ${widget.title}', style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_rowCount rows from ${multiple ? '${widget.groups.length} schedules' : 'the selection'}.'),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Columns', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _columns.addAll(widget.columns.map((c) => c.id))),
                  child: const Text('All'),
                ),
                TextButton(onPressed: () => setState(_columns.clear), child: const Text('None')),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final column in widget.columns)
                  FilterChip(
                    label: Text(column.label, style: const TextStyle(fontSize: 12)),
                    selected: _columns.contains(column.id),
                    visualDensity: VisualDensity.compact,
                    onSelected: (on) => setState(() => on ? _columns.add(column.id) : _columns.remove(column.id)),
                  ),
              ],
            ),
            if (multiple) ...[
              const SizedBox(height: 10),
              Text('Files', style: Theme.of(context).textTheme.titleSmall),
              RadioGroup<bool>(
                groupValue: _separate,
                onChanged: (value) => setState(() => _separate = value ?? false),
                child: const Column(
                  children: [
                    RadioListTile<bool>(dense: true, value: false, title: Text('One file with everything')),
                    RadioListTile<bool>(dense: true, value: true, title: Text('A separate file for each schedule')),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text('Export as', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _export('PDF'),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _export('Word'),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Word'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _export('CSV'),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _whatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp message'),
                ),
              ],
            ),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!)),
            for (final saved in _saved)
              Card(
                child: ListTile(
                  dense: true,
                  title: Text(saved.result.fileName, overflow: TextOverflow.ellipsis),
                  subtitle: Text(saved.result.displayPath ?? saved.format),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Open',
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => (widget.open ?? FileSaveHelper.openFile)(saved.result.filePath),
                      ),
                      IconButton(
                        tooltip: 'Share',
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () => _share(saved, whatsApp: false),
                      ),
                      IconButton(
                        tooltip: 'Send this file on WhatsApp',
                        icon: const Icon(Icons.chat_outlined),
                        onPressed: () => _share(saved, whatsApp: true),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }

  Future<void> _share(_Saved saved, {required bool whatsApp}) async {
    final path = saved.result.filePath;
    final share = widget.share;
    if (share != null) {
      await share(path, whatsApp: whatsApp);
      return;
    }
    await FileSaveHelper.shareFile(path, preferWhatsApp: whatsApp);
  }
}
