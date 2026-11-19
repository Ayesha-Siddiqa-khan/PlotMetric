import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/scheme_catalog.dart';
import '../../../core/utils/native_platform_helper.dart';
import '../../../data/models/calculation.dart';
import '../../../data/models/measurement_entry.dart';
import '../../export/presentation/calculation_export_dialog.dart';
import '../../land/logic/land_math.dart';
import '../../approved_land/logic/approved_land.dart';
import '../../approved_land/logic/approved_land_repository.dart';
import '../logic/scheme.dart';
import '../logic/scheme_repository.dart';
import '../logic/scheme_scan.dart';
import 'crop_image_screen.dart';
import 'scheme_editors.dart';

typedef SchemeScanResult = ({List<SchemeRow> rows, String? crop});

class SchemeScanScreen extends StatefulWidget {
  const SchemeScanScreen({
    super.key,
    this.initialImage,
    this.existingGross,
    this.embedded = false,
    this.tab = false,
    this.approved,
  });
  final String? initialImage;
  final SchemeRow? existingGross;

  /// True when opened from the scheme worksheet, which receives the rows back.
  final bool embedded;

  /// True when shown as the Scan tab (no back arrow).
  final bool tab;

  /// The Approved Land row this scan belongs to; its name and total area are prefilled.
  final ApprovedLandEntry? approved;

  @override
  State<SchemeScanScreen> createState() => _SchemeScanScreenState();
}

class _SchemeScanScreenState extends State<SchemeScanScreen> {
  final _rows = <SchemeRow>[];
  final _checked = <int>{};
  int _next = 1;
  String? _crop;
  String? _message;
  bool _busy = false;
  final _tKanal = TextEditingController();
  final _tMarla = TextEditingController();
  final _tSarsai = TextEditingController();
  final _repo = SchemeRepository();
  final _approvedRepo = ApprovedLandRepository();
  ApprovedLandEntry? _approved;
  HousingScheme? _saved;
  List<String> _names = SchemeCatalog.colonies;
  String _name = '';
  bool _saving = false;
  bool _dirty = false;
  int _nameReset = 0;

  @override
  void dispose() {
    _tKanal.dispose();
    _tMarla.dispose();
    _tSarsai.dispose();
    super.dispose();
  }

  /// Reopens the scan saved earlier for this colony instead of starting empty.
  Future<void> _restore(int schemeId) async {
    try {
      final scheme = await _repo.load(schemeId);
      if (!mounted) return;
      final rows = scheme.scanRows.isNotEmpty ? scheme.scanRows : scheme.rows;
      final checked = scheme.scanRows.isNotEmpty
          ? scheme.scanChecked
          : scheme.rows.map((row) => row.id).toSet();
      setState(() {
        _saved = scheme;
        _rows
          ..clear()
          ..addAll(rows.map((row) => SchemeRow.fromJson(row.toJson())));
        _checked
          ..clear()
          ..addAll(checked);
        _next = rows.map((row) => row.id).fold(0, (a, b) => a > b ? a : b) + 1;
        _crop = scheme.scheduleCrop;
        _name = scheme.name;
        _nameReset++;
        _tKanal.text = scheme.transferredKanal;
        _tMarla.text = scheme.transferredMarla;
        _tSarsai.text = scheme.transferredSarsai;
        _dirty = false;
      });
    } catch (_) {
      // The earlier scan is gone from Records; start a fresh one.
      if (mounted) _toast('The earlier scan for this colony could not be reopened. Scan it again.');
    }
  }

  String _transferredText() {
    if ([_tKanal, _tMarla, _tSarsai].every((c) => c.text.trim().isEmpty)) return '';
    String part(TextEditingController c) => c.text.trim().isEmpty ? '0' : c.text.trim();
    return '${part(_tKanal)}K-${part(_tMarla)}M-${part(_tSarsai)}S';
  }

  /// Writes the scan result onto the Approved Land row (by id, else by matching name).
  Future<void> _updateRegister(HousingScheme scheme, List<SchemeRow> selected) async {
    final ticked = selected.where((row) => row.classification == AreaClass.transfer).toList();
    final due = (HousingScheme()..rows.addAll(ticked)).totals.due;
    final int? transferArea = ticked.isEmpty ? null : due;
    final grossRow = _rows.where((row) => row.classification == AreaClass.gross && row.area != null).firstOrNull;
    var entry = _approved;
    entry ??= await _approvedRepo.byName(scheme.name);
    if (entry == null || entry.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This colony is not in the Approved Land register.'),
            action: SnackBarAction(
              label: 'Add it',
              onPressed: () async {
                final added = ApprovedLandEntry(name: scheme.name, totalArea: LandAreaText.format(grossRow?.area));
                await _approvedRepo.save(added);
                await _approvedRepo.applyScan(
                  added.id!,
                  schemeId: scheme.id!,
                  transferArea: transferArea,
                  transferred: _transferredText(),
                );
                if (mounted) _toast('Added "${scheme.name}" to Approved Land.');
              },
            ),
          ),
        );
      }
      return;
    }
    _approved = entry;
    await _approvedRepo.applyScan(
      entry.id!,
      schemeId: scheme.id!,
      transferArea: transferArea,
      transferred: _transferredText(),
      totalAreaIfEmpty: grossRow == null ? '' : LandAreaText.format(grossRow.area),
    );
  }

  Future<void> _loadNames() async {
    try {
      final names = await _repo.names();
      if (mounted) setState(() => _names = names);
    } catch (_) {
      // The bundled suggestions stay available without the local database.
    }
  }

  Future<void> _save(List<SchemeRow> selected) async {
    if (_name.trim().isEmpty) {
      _toast('Enter the scheme name before saving.');
      return;
    }
    if (_rows.isEmpty) {
      _toast('Scan or add the schedule rows before saving.');
      return;
    }
    setState(() => _saving = true);
    try {
      final scheme = (_saved ?? HousingScheme())
        ..name = _name.trim()
        ..selectedOnly = true
        ..reviewed = false
        ..scheduleCrop = _crop
        ..transferredKanal = _tKanal.text.trim()
        ..transferredMarla = _tMarla.text.trim()
        ..transferredSarsai = _tSarsai.text.trim();
      scheme.rows.clear();
      for (final row in selected) {
        scheme.rows.add(SchemeRow.fromJson(row.toJson()..['id'] = scheme.nextRowId()));
      }
      scheme.scanRows
        ..clear()
        ..addAll(_rows.map((row) => SchemeRow.fromJson(row.toJson())));
      scheme.scanChecked
        ..clear()
        ..addAll(_checked);
      await _repo.save(scheme);
      if (!mounted) return;
      _saved = scheme;
      setState(() => _dirty = false);
      _toast('Saved "${scheme.name}". It is kept permanently in Records.');
      try {
        await _updateRegister(scheme, selected);
        if (mounted && _approved != null) {
          _toast('Saved "${scheme.name}" and updated it in Approved Land.');
        }
      } catch (_) {
        if (mounted) _toast('Saved, but could not update the Approved Land register.');
      }
    } catch (_) {
      _toast('Could not save. Check the scheme name and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// An editable example schedule, for when there is no image or the scan could not be read.
  Future<void> _loadSample() async {
    if (_rows.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Replace the rows with the sample?'),
          content: Text(
            'The rows on this page will be replaced by an editable sample schedule.'
            '${_approved == null ? '' : ' Saving will write the figures into "${_approved!.name}" in Approved Land.'}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Replace')),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    const sample = <(String, String, String, String, String, AreaClass)>[
      ('TOTAL AREA', '283140', '52', '0', '0', AreaClass.gross),
      ('RESIDENTIAL AREA', '177607', '32', '12', '2', AreaClass.plot),
      ('TOTAL ROAD AREA', '71670', '13', '3', '2', AreaClass.transfer),
      ('COMMERCIAL AREA', '5662', '1', '0', '8', AreaClass.plot),
      ('PARK & GREEN BELT', '19817', '3', '12', '7', AreaClass.transfer),
      ('PUBLIC BUILDING MOSQUE (17M-8S) DISPENSARY (3M)', '5662', '1', '0', '8', AreaClass.transfer),
      ('SOLID WASTE MANAGEMENT & DISPOSAL', '2722', '0', '10', '0', AreaClass.transfer),
    ];
    setState(() {
      _rows
        ..clear()
        ..addAll([
          for (final (i, (description, sft, k, m, s, kind)) in sample.indexed)
            SchemeRow(
              i + 1,
              description: description,
              sft: sft,
              kanal: k,
              marla: m,
              sarsai: s,
              classification: kind,
            ),
        ]);
      _checked.clear();
      _next = sample.length + 1;
      _message = 'This is a sample schedule. Tap the edit icon on any row to change it to your own figures.';
      _dirty = true;
    });
  }

  /// Marks a row as the total area of the whole scheme: it becomes row 1 and every other row's % is a share of it.
  void _makeTotal(int index) => setState(() {
    final chosen = _rows.removeAt(index)..classification = AreaClass.gross;
    for (final row in _rows) {
      if (row.classification == AreaClass.gross) row.classification = AreaClass.review;
    }
    _rows.insert(0, chosen);
    _dirty = true;
  });

  void _newScan() => setState(() {
    _rows.clear();
    _checked.clear();
    _crop = null;
    _message = null;
    _name = _approved?.name ?? '';
    _saved = null;
    _dirty = false;
    _nameReset++;
    for (final controller in [_tKanal, _tMarla, _tSarsai]) {
      controller.clear();
    }
    _dirty = false;
  });

  MeasurementEntry _entry(int order, String title, int? area, EntryOperation operation) {
    final units = area == null ? 0 : (area.abs() + SchemeArea.unit ~/ 2) ~/ SchemeArea.unit;
    final composite = LandMath.centiSarsaiToComposite(units);
    return MeasurementEntry(
      sortOrder: order,
      purpose: title,
      operation: operation,
      kanal: composite.kanal,
      marla: composite.marla,
      sarsaiCenti: composite.sarsaiCenti,
    );
  }

  /// PDF / Word / CSV report: selected rows, less what is already transferred.
  void _export(List<SchemeRow> selected) {
    final rows = selected.where((row) => row.classification == AreaClass.transfer && row.ready).toList();
    if (rows.isEmpty) {
      _toast('Tick at least one complete row to export.');
      return;
    }
    String part(TextEditingController c) => c.text.trim().isEmpty ? '0' : c.text.trim();
    final done = SchemeArea.land(part(_tKanal), part(_tMarla), part(_tSarsai));
    if (done == null) {
      _toast('Correct the already-transferred numbers first.');
      return;
    }
    final now = DateTime.now();
    final entries = [
      for (final (i, row) in rows.indexed)
        _entry(i, row.description.trim().isEmpty ? 'Nil' : row.description.trim(), row.area, EntryOperation.add),
      if (done > 0) _entry(rows.length, 'Already transferred', done, EntryOperation.subtract),
    ];
    CalculationExportDialog.show(
      context,
      Calculation(
        title: _name.trim().isEmpty ? 'Area schedule' : _name.trim(),
        calculationDate: now.toIso8601String().split('T').first,
        calculationTime: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        createdAtUtc: now.toUtc().toIso8601String(),
        updatedAtUtc: now.toUtc().toIso8601String(),
        entries: entries,
      ),
      subtitle: 'AREA TRANSFER REPORT',
      summaryTitle: 'TRANSFER SUMMARY & REMAINING AREA',
      totalAreaLabel: 'Total area to transfer (+)',
      deductionsLabel: 'Already transferred (-)',
      netLabel: 'REMAINING TO TRANSFER',
    );
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void initState() {
    super.initState();
    _loadNames();
    if (widget.approved case final entry?) {
      _approved = entry;
      _name = entry.name;
      if (entry.schemeId != null) _restore(entry.schemeId!);
    }
    for (final controller in [_tKanal, _tMarla, _tSarsai]) {
      controller.addListener(() => _dirty = true);
    }
    if (widget.initialImage case final path?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scan(false, imagePath: path);
      });
    }
  }

  Future<void> _scan(bool camera, {String? imagePath}) async {
    setState(() => _busy = true);
    try {
      final crop = imagePath == null
          ? await CropImageScreen.pick(context, camera: camera)
          : await CropImageScreen.open(context, imagePath);
      if (crop == null || !mounted) return;
      final source = base64Encode(crop.preview);
      setState(() {
        _crop = source;
        _rows.clear();
        _checked.clear();
        _message = null;
      });
      if (!NativePlatformHelper.canRecognizeTable) {
        setState(
          () => _message =
              'Enter the rows from the crop. Automatic table recognition is available on Android and Windows.',
        );
        return;
      }
      final words = await CropImageScreen.withScanFile(
        crop.scan,
        NativePlatformHelper.recognizeImageTable,
      );
      final parsed = SchemeScan.read(
        words.map((value) {
          final map = value as Map;
          return (
            text: map['text'] as String,
            x: (map['x'] as num).toDouble(),
            y: (map['y'] as num).toDouble(),
            height: (map['height'] as num).toDouble(),
          );
        }),
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(parsed);
        _next = parsed.length + 1;
        if (parsed.isEmpty) {
          _message =
              'No text was found. Try a closer crop or add the rows manually.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not read the table. Check the crop or add the rows manually.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(int? index) async {
    final row = await editSchemeRow(
      context,
      index == null ? SchemeRow(_next++) : _rows[index],
    );
    if (row == null || !mounted) return;
    setState(() {
      if (index == null) {
        _rows.add(row);
      } else {
        _rows[index] = row;
      }
    });
  }

  Future<void> _split(int index) async {
    final rows = await splitScheduleRow(context, _rows[index], _next++);
    if (rows == null || !mounted) return;
    setState(() {
      if (_checked.contains(_rows[index].id)) {
        _checked.addAll(rows.map((row) => row.id));
      }
      _rows.replaceRange(index, index + 1, rows);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = SchemeScan.selectedRows(_rows, _checked);
    final gross = widget.existingGross;
    final selectedGross = selected.where((row) => row.classification == AreaClass.gross).length;
    final totals = (HousingScheme()..rows.addAll([?gross, ...selected])).totals;
    final registerTotal = _approved == null ? null : LandAreaText.parse(_approved!.totalArea);
    // The scanned Total Area row is 100%, and every other row is its share of it.
    final scannedTotal = _rows
        .where((row) => row.classification == AreaClass.gross && (row.area ?? 0) > 0)
        .map((row) => row.area!)
        .firstOrNull;
    final previewGross = scannedTotal ?? gross?.area ?? registerTotal;
    final canSend = selected.isNotEmpty && selectedGross == (gross == null ? 1 : 0);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan area schedule'),
        automaticallyImplyLeading: !widget.tab,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_approved case final entry?)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(entry.name),
                  subtitle: Text(
                    'Approved Land total area: ${entry.totalArea.isEmpty ? 'not entered' : entry.totalArea}'
                    '${entry.mouza.isEmpty ? '' : '\n${entry.mouza}'}',
                  ),
                ),
              ),
            const Text(
              'Tap a description to correct it. Tick the rows you want, type what is already transferred, then Save.',
            ),
            const SizedBox(height: 8),
            schemeSuggestionField(
              key: ValueKey(_nameReset),
              label: 'Scheme name',
              value: _name,
              suggestions: _names,
              onChanged: (text) => _name = text,
              maxLength: 120,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (Platform.isAndroid || Platform.isWindows)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _scan(true),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take photo'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _scan(false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose image'),
                ),
                if (_crop case final crop?)
                  cropPreview(context, crop, 'View crop'),
                TextButton.icon(
                  onPressed: _busy ? null : () => _edit(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add row'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _loadSample,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Sample schedule'),
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!),
              ),
            if (_rows.isEmpty && !_busy && _message == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '1. Choose an image of the area schedule (or take a photo).\n'
                  '2. Crop to the table, including the header row.\n'
                  '3. Check the rows, tick the ones you want, type what is already transferred.\n'
                  '4. Save, or export a PDF / Word / CSV report.',
                ),
              ),
            if (_rows.isNotEmpty)
              ScheduleTable(
                rows: _rows,
                grossArea: previewGross,
                checkedRows: _checked,
                edit: _busy ? null : _edit,
                split: _busy ? null : _split,
                makeTotal: _busy ? null : _makeTotal,
                transfer: _busy
                    ? null
                    : (index, checked) => setState(
                        () {
                          _dirty = true;
                          checked ? _checked.add(_rows[index].id) : _checked.remove(_rows[index].id);
                        },
                      ),
                remove: _busy
                    ? null
                    : (index) => setState(() => _checked.remove(_rows.removeAt(index).id)),
              ),
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectedAreaSummary(
                rows: selected.where((row) => row.classification == AreaClass.transfer).toList(),
                due: totals.due,
                transferredKanal: _tKanal,
                transferredMarla: _tMarla,
                transferredSarsai: _tSarsai,
              ),
              const SizedBox(height: 8),
              Text('Selected transferable: ${SchemeArea.display(totals.due)}'),
              if (totals.grossLessTransferable case final remaining?)
                Text(
                  'Gross less transferable: ${SchemeArea.display(remaining)}',
                ),
              if (selected.any(
                (row) => row.classification == AreaClass.transfer && !row.ready,
              ))
                const Text('Selected rows with unresolved values are pending.'),
              if (widget.embedded && !canSend) Text(gross == null
                  ? 'Check exactly one Total Area row to send the selection.'
                  : 'The worksheet already has a total area. Select only additional transferable rows.'),
            ],
            if (_rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy || _saving ? null : () => _save(selected),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saved == null ? 'Save' : (_dirty ? 'Save changes' : 'Saved')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _export(selected),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Export PDF / Word / CSV'),
                    ),
                    TextButton.icon(
                      onPressed: _busy || _saving ? null : _newScan,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('New scan'),
                    ),
                    if (widget.embedded)
                      OutlinedButton(
                        onPressed: _busy || !canSend
                            ? null
                            : () => Navigator.pop(context, (rows: selected, crop: _crop)),
                        child: const Text('Add to scheme worksheet'),
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

({String k, String m, String s}) _kms(int? area) {
  if (area == null) return (k: '—', m: '—', s: '—');
  final rounded = (area.abs() + SchemeArea.unit ~/ 2) ~/ SchemeArea.unit;
  final c = LandMath.centiSarsaiToComposite(area < 0 ? -rounded : rounded);
  final sign = c.isNegative ? '-' : '';
  return (k: '$sign${c.kanal}', m: '${c.marla}', s: c.sarsaiFormatted);
}

/// Totals of the ticked rows (Kanal/Marla/Sarsai), plus a manual "already
/// transferred" entry and the remaining balance.
class SelectedAreaSummary extends StatelessWidget {
  const SelectedAreaSummary({
    super.key,
    required this.rows,
    required this.due,
    required this.transferredKanal,
    required this.transferredMarla,
    required this.transferredSarsai,
  });
  final List<SchemeRow> rows;
  final int due;
  final TextEditingController transferredKanal, transferredMarla, transferredSarsai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bold = theme.textTheme.titleSmall;
    TableRow line(String a, String k, String m, String s, String sft, {TextStyle? style}) =>
        TableRow(
          children: [
            for (final (i, text) in [a, k, m, s, sft].indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  text,
                  style: style,
                  textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                ),
              ),
          ],
        );
    final total = _kms(due);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Selected area total', style: bold),
            const SizedBox(height: 6),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(2),
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: theme.dividerColor),
                bottom: BorderSide(color: theme.dividerColor),
              ),
              children: [
                line('Description', 'Kanal', 'Marla', 'Sarsai', 'Sq ft', style: bold),
                for (final row in rows)
                  line(
                    row.description.isEmpty ? 'Unreadable description' : row.description,
                    _kms(row.ready ? row.area : null).k,
                    _kms(row.ready ? row.area : null).m,
                    _kms(row.ready ? row.area : null).s,
                    SchemeArea.display(row.ready ? row.area : null).replaceAll(' sq ft', ''),
                  ),
                line('Total', total.k, total.m, total.s,
                    SchemeArea.display(due).replaceAll(' sq ft', ''), style: bold),
              ],
            ),
            const SizedBox(height: 14),
            Text('Already transferred (type manually)', style: bold),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final (label, controller) in [
                  ('Kanal', transferredKanal),
                  ('Marla', transferredMarla),
                  ('Sarsai', transferredSarsai),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: label, isDense: true),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ListenableBuilder(
              listenable: Listenable.merge([transferredKanal, transferredMarla, transferredSarsai]),
              builder: (context, _) {
                String part(TextEditingController c) => c.text.trim().isEmpty ? '0' : c.text.trim();
                final empty = [transferredKanal, transferredMarla, transferredSarsai]
                    .every((c) => c.text.trim().isEmpty);
                final done = SchemeArea.land(
                  part(transferredKanal),
                  part(transferredMarla),
                  part(transferredSarsai),
                );
                if (done == null) {
                  return Text(
                    'Enter valid numbers (Marla below 20, Sarsai below 9).',
                    style: TextStyle(color: theme.colorScheme.error),
                  );
                }
                final remaining = due - done;
                final r = _kms(remaining);
                final d = _kms(done);
                return Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                    4: FlexColumnWidth(2),
                  },
                  border: TableBorder(horizontalInside: BorderSide(color: theme.dividerColor)),
                  children: [
                    line('Report', 'Kanal', 'Marla', 'Sarsai', 'Sq ft', style: bold),
                    line('To transfer', total.k, total.m, total.s,
                        SchemeArea.display(due).replaceAll(' sq ft', '')),
                    line('Transferred', d.k, d.m, d.s,
                        SchemeArea.display(empty ? 0 : done).replaceAll(' sq ft', '')),
                    line(remaining < 0 ? 'Excess' : 'Remaining', r.k, r.m, r.s,
                        SchemeArea.display(remaining.abs()).replaceAll(' sq ft', ''), style: bold),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<List<SchemeRow>?> splitScheduleRow(
  BuildContext context,
  SchemeRow original,
  int newId,
) async {
  final first = await editSchemeRow(
    context,
    SchemeRow(original.id, source: original.source, needsReview: true),
  );
  if (first == null || !context.mounted) return null;
  final second = await editSchemeRow(
    context,
    SchemeRow(newId, source: original.source, needsReview: true),
  );
  if (second == null || !context.mounted) return null;
  if (original.area case final total?) {
    if (first.area == null ||
        second.area == null ||
        first.area! + second.area! != total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The split must equal the source row area.'),
        ),
      );
      return null;
    }
  }
  return [first, second];
}

class ScheduleTable extends StatelessWidget {
  const ScheduleTable({
    super.key,
    required this.rows,
    required this.grossArea,
    this.checkedRows,
    this.edit,
    this.split,
    this.remove,
    this.transfer,
    this.makeTotal,
  });
  final List<SchemeRow> rows;
  final int? grossArea;
  final Set<int>? checkedRows;
  final ValueChanged<int>? edit, split, remove, makeTotal;
  final void Function(int, bool)? transfer;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      horizontalMargin: 8,
      columnSpacing: 10,
      columns: [
        for (final label in [
          'S.No',
          checkedRows == null ? 'Transfer' : 'Send',
          'Description',
          'Kanal',
          'Marla',
          'Sarsai',
          'Calculated sq ft',
          '%',
          'Classification',
          if (rows.any((row) => row.mortgageSft.isNotEmpty)) 'Mortgage sq ft',
          'Actions',
        ])
          DataColumn(label: Text(label)),
      ],
      rows: [
        for (final (index, row) in rows.indexed)
          DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(
                Checkbox(
                  value: checkedRows?.contains(row.id) ?? (row.classification == AreaClass.transfer),
                  semanticLabel: checkedRows == null
                      ? 'Transferable: ${row.description}'
                      : 'Send to Land: ${row.description}',
                  onChanged:
                      transfer == null || row.classification == AreaClass.subtotal ||
                          (checkedRows == null && [AreaClass.gross, AreaClass.plot].contains(row.classification))
                      ? null
                      : (checked) => transfer!(index, checked == true),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width < 600 ? 94 : 200,
                  ),
                  child: Text(
                    row.description.isEmpty
                        ? 'Unreadable description'
                        : row.description,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                onTap: edit == null ? null : () => edit!(index),
              ),
              for (final value in [
                row.kanal,
                row.marla,
                row.sarsai,
                SchemeArea.display(
                  row.area ?? row.printedSft,
                ),
                row.percent.trim().isNotEmpty
                    ? '${row.percent.trim()}%'
                    : SchemeArea.percentDisplay(
                        row.area,
                        grossArea,
                      ),
                row.ready ? row.classification.label : 'Needs review',
              ])
                DataCell(Text(value)),
              if (rows.any((row) => row.mortgageSft.isNotEmpty))
                DataCell(Text(row.mortgageSft)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit row ${index + 1}',
                      onPressed: edit == null ? null : () => edit!(index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Row actions',
                      enabled: split != null || remove != null,
                      onSelected: (value) => switch (value) {
                        'split' => split?.call(index),
                        'total' => makeTotal?.call(index),
                        _ => remove?.call(index),
                      },
                      itemBuilder: (context) => [
                        if (makeTotal != null && row.classification != AreaClass.gross)
                          const PopupMenuItem(
                            value: 'total',
                            child: Text('Use as Total Area (row 1)'),
                          ),
                        if (split != null)
                          const PopupMenuItem(
                            value: 'split',
                            child: Text('Split row'),
                          ),
                        if (remove != null)
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove row'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    ),
  );
}
