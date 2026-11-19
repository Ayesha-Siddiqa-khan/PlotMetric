import 'package:flutter/material.dart';

import '../../../core/constants/scheme_catalog.dart';
import '../../export/logic/file_save_helper.dart';
import '../../export/logic/pdf_export_service.dart';
import '../logic/scheme.dart';
import '../logic/scheme_report.dart';
import '../logic/scheme_repository.dart';
import 'scheme_editors.dart';
import 'scheme_scan_screen.dart';
import 'scheme_register.dart';

class SchemeScreen extends StatefulWidget {
  const SchemeScreen({super.key, this.existing, this.scanned});
  final HousingScheme? existing;
  final SchemeScanResult? scanned;

  static Future<void> open(
    BuildContext context, {
    HousingScheme? existing,
    SchemeScanResult? scanned,
  }) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SchemeScreen(existing: existing, scanned: scanned),
    ),
  );

  @override
  State<SchemeScreen> createState() => _SchemeScreenState();
}

class _SchemeScreenState extends State<SchemeScreen> {
  late final _scheme = widget.existing ?? HousingScheme();
  final _repo = SchemeRepository();
  List<String> _colonyNames = SchemeCatalog.colonies;
  final _scroll = ScrollController();
  bool _saving = false;
  bool _dirty = false;
  bool _leaving = false;
  ExportFileResult? _exported;
  String? _status;

  @override
  void initState() {
    super.initState();
    if (widget.scanned case final scan?) _applyScan(scan);
    _loadColonyNames();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadColonyNames() async {
    try {
      final names = await _repo.names();
      if (mounted) setState(() => _colonyNames = names);
    } catch (_) {
      // The bundled titles remain available while the local register is unavailable.
    }
  }

  void _applyScan(SchemeScanResult scan) {
    _scheme.selectedOnly = true;
    for (final row in scan.rows) {
      _scheme.rows.add(
        SchemeRow.fromJson(row.toJson()..['id'] = _scheme.nextRowId()),
      );
    }
    if (scan.crop != null) _scheme.scheduleCrop = scan.crop;
    _scheme.reviewed = false;
    _dirty = true;
  }

  void _change(VoidCallback update, {bool schedule = false}) {
    setState(() {
      update();
      if (schedule) _scheme.reviewed = false;
      _dirty = true;
      _exported = null;
    });
  }

  Future<void> _scan() async {
    final scan = await Navigator.push<SchemeScanResult>(
      context,
      MaterialPageRoute(builder: (_) => SchemeScanScreen(
        embedded: true,
        existingGross: _scheme.rows.where((row) => row.classification == AreaClass.gross).firstOrNull,
      )),
    );
    if (scan != null && mounted) _change(() => _applyScan(scan));
  }

  Future<void> _editRow(int? index) async {
    final row = await editSchemeRow(
      context,
      index == null ? SchemeRow(_scheme.nextRowId()) : _scheme.rows[index],
    );
    if (row == null || !mounted) return;
    _change(() {
      if (index == null) {
        _scheme.rows.add(row);
      } else {
        final previous = _scheme.rows[index];
        if (previous.area != row.area ||
            previous.ready != row.ready ||
            previous.classification != row.classification ||
            previous.description != row.description) {
          _invalidateEvidence(row.id);
        }
        _scheme.rows[index] = row;
      }
    }, schedule: true);
  }

  bool _linked(SchemeRow row) =>
      _scheme.evidence.any((doc) => doc.allocations.containsKey(row.id));
  void _invalidateEvidence(int rowId) {
    for (final doc in _scheme.evidence.where(
      (doc) => doc.allocations.containsKey(rowId),
    )) {
      doc.verified = false;
    }
  }

  Future<void> _split(int index) async {
    if (_linked(_scheme.rows[index])) {
      _notify('Remove the transfer allocations before splitting this row.');
      return;
    }
    final rows = await splitScheduleRow(
      context,
      _scheme.rows[index],
      _scheme.nextRowId(),
    );
    if (rows != null && mounted) {
      _change(
        () => _scheme.rows.replaceRange(index, index + 1, rows),
        schedule: true,
      );
    }
  }

  void _removeRow(int index) {
    if (_linked(_scheme.rows[index])) {
      _notify('Remove the transfer allocations before deleting this row.');
      return;
    }
    _change(() => _scheme.rows.removeAt(index), schedule: true);
  }

  Future<void> _editDoc(int? index) async {
    final doc = await editEvidence(
      context,
      _scheme,
      index == null ? null : _scheme.evidence[index],
    );
    if (doc == null || !mounted) return;
    final duplicate = _scheme.evidence.indexWhere(
      (other) =>
          doc.key.isNotEmpty && other.type == doc.type && other.key == doc.key,
    );
    if (duplicate >= 0 && duplicate != index) {
      _notify('This document is already recorded. Edit the existing entry.');
      return;
    }
    _change(() {
      if (index == null) {
        _scheme.evidence.add(doc);
      } else {
        _scheme.evidence[index] = doc;
      }
    });
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save({String? format}) async {
    if (_scheme.name.trim().isEmpty) {
      _notify('Enter the scheme name before saving.');
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _status = null;
      _exported = null;
    });
    var saved = false;
    try {
      await _repo.save(_scheme);
      saved = true;
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _status = 'Scheme saved in Records.';
      });
      if (format == null) return;
      final report = SchemeReport(_scheme);
      final bytes = format == 'xlsx'
          ? report.excelBytes()
          : PdfExportService.generateSchemePdf(report);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final result = await FileSaveHelper.saveBinaryFile(
        fileName: '${_scheme.name}_$timestamp.$format',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _exported = result.success ? result : null;
        _status = result.success
            ? 'Saved ${result.fileName}'
            : result.errorMessage;
      });
      if (result.success) _notify('Export saved. Open or share it below.');
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = saved
              ? 'Scheme saved. Export failed: $error'
              : 'Could not save scheme: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (_saving || _leaving) return;
    _leaving = true;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Unsaved scheme changes'),
          content: const Text(
            'Discard your edits and return to the previous screen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Discard edits'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) Navigator.pop(context);
    } finally {
      _leaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _scheme.totals;
    final saving = _saving;
    final issues = _scheme.scheduleIssues;
    return PopScope<void>(
      canPop: !_dirty && !saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Housing Scheme')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: IgnorePointer(
                ignoring: saving,
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (saving) const LinearProgressIndicator(),
                    Text(
                      'Scheme details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    schemeSuggestionField(
                      label: 'Scheme name',
                      value: _scheme.name,
                      suggestions: _colonyNames,
                      onChanged: (text) => _change(() => _scheme.name = text),
                      maxLength: 120,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.list_alt_outlined),
                        label: const Text('Manage office register'),
                        onPressed: () async {
                          await SchemeRegister.open(context);
                          if (mounted) await _loadColonyNames();
                        },
                      ),
                    ),
                    schemeField(
                      'Block / phase',
                      _scheme.block,
                      (text) => _change(() => _scheme.block = text),
                      maxLength: 100,
                    ),
                    schemeField(
                      'Owner / developer names',
                      _scheme.owner,
                      (text) => _change(() => _scheme.owner = text),
                      maxLength: 240,
                    ),
                    schemeField(
                      'Location',
                      _scheme.location,
                      (text) => _change(() => _scheme.location = text),
                      maxLength: 200,
                    ),
                    schemeField(
                      'Municipal recipient',
                      _scheme.recipient,
                      (text) => _change(() {
                        _scheme.recipient = text;
                        for (final doc in _scheme.evidence) {
                          doc.verified = false;
                        }
                      }),
                      maxLength: 150,
                    ),
                    schemeField(
                      'Approval reference',
                      _scheme.approval,
                      (text) => _change(() => _scheme.approval = text),
                      maxLength: 100,
                    ),
                    const Divider(),
                    Text(
                      'Area schedule',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _scan,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Scan table'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _editRow(null),
                          icon: const Icon(Icons.add),
                          label: const Text('Add row'),
                        ),
                        if (_scheme.scheduleCrop case final crop?)
                          cropPreview(context, crop, 'View schedule crop'),
                      ],
                    ),
                    if (_scheme.rows.isNotEmpty)
                      ScheduleTable(
                        rows: _scheme.rows,
                        grossArea: totals.gross,
                        edit: _editRow,
                        split: _split,
                        remove: _removeRow,
                        transfer: (index, checked) => _change(() {
                          _invalidateEvidence(_scheme.rows[index].id);
                          _scheme.rows[index].classification = checked
                              ? AreaClass.transfer
                              : AreaClass.other;
                        }, schedule: true),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Area schedule reviewed'),
                      subtitle: issues.isEmpty ? null : Text(issues.first),
                      value: _scheme.reviewed && issues.isEmpty,
                      onChanged: issues.isEmpty
                          ? (value) =>
                                _change(() => _scheme.reviewed = value == true)
                          : null,
                    ),
                    _summary('Map reconciliation', [
                      ('Gross area', totals.gross),
                      ('Non-plot area', totals.nonPlot),
                      ('Calculated plot area', totals.calculatedPlots),
                      ('Printed owner-plot area', totals.printedPlots),
                      ('Map difference', totals.mapDifference),
                    ]),
                    _summary('Transfer reconciliation', [
                      ('Due', totals.due),
                      ('Gross less transferable', totals.grossLessTransferable),
                      ('Verified transferred', totals.verified),
                      ('Outstanding', totals.remaining),
                      ('Excess transfer', totals.overage),
                      if (_scheme.rows.any((row) => row.mortgageSft.isNotEmpty))
                        ('Mortgage', totals.mortgage),
                    ]),
                    if (totals.dueRows.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 18,
                          columns: [
                            for (final name in [
                              'Category',
                              'Due',
                              'Verified',
                              'Outstanding',
                              'Excess',
                            ])
                              DataColumn(label: Text(name)),
                          ],
                          rows: [
                            for (final row in totals.dueRows)
                              DataRow(
                                cells: [
                                  DataCell(Text(row.description)),
                                  for (final area in [
                                    row.area,
                                    totals.transferred(row),
                                    totals.outstanding(row),
                                    totals.excess(row),
                                  ])
                                    DataCell(Text(SchemeArea.composite(area))),
                                ],
                              ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Text(
                      'Transfer evidence',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final (index, doc) in _scheme.evidence.indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          totals.isVerified(doc)
                              ? Icons.verified_outlined
                              : Icons.pending_outlined,
                        ),
                        title: Text(
                          '${doc.type.name.toUpperCase()} ${doc.reference}',
                        ),
                        subtitle: Text(
                          totals.isVerified(doc)
                              ? 'Verified • ${SchemeArea.composite(doc.area)}'
                              : 'Pending • ${_scheme.evidenceIssue(doc) ?? 'Officer verification required'}',
                        ),
                        onTap: () => _editDoc(index),
                        trailing: IconButton(
                          tooltip: 'Remove evidence',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeDoc(index),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _editDoc(null),
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('Add Fard / Intiqal'),
                      ),
                    ),
                    if (totals.issues.isNotEmpty)
                      ExpansionTile(
                        title: const Text('Outstanding review items'),
                        children: [
                          for (final issue in totals.issues)
                            ListTile(dense: true, title: Text(issue)),
                        ],
                      ),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => _save(),
                          child: const Text('Save scheme'),
                        ),
                        OutlinedButton(
                          onPressed: () => _save(format: 'pdf'),
                          child: const Text('Save & Export PDF'),
                        ),
                        OutlinedButton(
                          onPressed: () => _save(format: 'xlsx'),
                          child: const Text('Save & Export Excel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await editExportLayout(context, _scheme);
                            if (mounted) _change(() {});
                          },
                          child: const Text('Report columns'),
                        ),
                      ],
                    ),
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_status!),
                      ),
                    if (_exported case final result?)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final opened = await FileSaveHelper.openFile(
                                result.filePath,
                              );
                              if (mounted && !opened) {
                                _notify('No app could open this report.');
                              }
                            },
                            child: const Text('Open report'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final shared = await FileSaveHelper.shareFile(
                                result.filePath,
                              );
                              if (mounted && !shared) {
                                _notify(
                                  'Use the saved file in your file manager.',
                                );
                              }
                            },
                            child: const Text('Share report'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _removeDoc(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove transfer evidence?'),
        content: const Text(
          'Any credit from this document will be removed from the scheme balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _change(() => _scheme.evidence.removeAt(index));
    }
  }

  Widget _summary(String title, List<(String, int?)> rows) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          for (final (label, amount) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                '$label   ${SchemeArea.composite(amount)}   •   ${SchemeArea.display(amount)}',
              ),
            ),
        ],
      ),
    ),
  );
}
