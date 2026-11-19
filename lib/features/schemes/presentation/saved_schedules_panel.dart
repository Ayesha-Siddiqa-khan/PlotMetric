import 'package:flutter/material.dart';

import '../../export/logic/table_formats.dart';
import '../../export/presentation/table_export_dialog.dart';
import '../logic/schedule_export.dart';
import '../logic/scheme_repository.dart';
import 'scheme_scan_screen.dart';

/// Every area schedule saved from the Scan page, on the Records page: open one to see its table
/// again, or tick some and export them as one file or one file each.
class SavedSchedulesPanel extends StatefulWidget {
  const SavedSchedulesPanel({super.key, this.isActive = true, this.repository});
  final bool isActive;
  final SchemeRepository? repository;

  @override
  State<SavedSchedulesPanel> createState() => _SavedSchedulesPanelState();
}

class _SavedSchedulesPanelState extends State<SavedSchedulesPanel> {
  late final SchemeRepository _repo = widget.repository ?? SchemeRepository();
  List<SchemeListItem> _items = [];
  final _selected = <int>{};
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SavedSchedulesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final items = await _repo.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _selected.removeWhere((id) => !items.any((item) => item.id == id));
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _open(SchemeListItem item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SchemeScanScreen(schemeId: item.id)),
    );
    if (mounted) _load();
  }

  Future<void> _export() async {
    final chosen = _selected.isEmpty ? _items : _items.where((item) => _selected.contains(item.id)).toList();
    if (chosen.isEmpty) return;
    try {
      final groups = <ExportGroup>[];
      for (final item in chosen) {
        final scheme = await _repo.load(item.id);
        final rows = scheme.scanRows.isNotEmpty ? scheme.scanRows : scheme.rows;
        final checked = scheme.scanRows.isNotEmpty ? scheme.scanChecked : {for (final row in scheme.rows) row.id};
        groups.add(scheduleGroup(scheme.name, rows, checked));
      }
      if (!mounted) return;
      await TableExportDialog.show(
        context,
        title: 'Saved area schedules',
        subtitle: 'PlotMetric - Kanal-Marla-Sarsai; square feet and % are calculated',
        columns: scheduleExportColumns,
        groups: groups,
        fileStem: chosen.length == 1 ? chosen.single.name : 'Area_Schedules',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load the schedules to export.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _items.isNotEmpty && _selected.length == _items.length;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.table_chart_outlined),
        title: Text('Saved area schedules (${_items.length})'),
        subtitle: const Text('Scanned tables kept for later. Tap a name to open it, tick to export.'),
        children: [
          if (_loading)
            const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator())
          else if (_failed)
            const Padding(padding: EdgeInsets.all(12), child: Text('Could not load the saved schedules.'))
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Nothing saved yet. Scan a schedule on the Scan tab and press Save.'),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected.addAll(_items.map((item) => item.id));
                      }
                    }),
                    child: Text(allSelected ? 'Clear selection' : 'Select all'),
                  ),
                  FilledButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.ios_share),
                    label: Text(_selected.isEmpty ? 'Export all' : 'Export (${_selected.length})'),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in _items)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selected.contains(item.id),
                      onChanged: (on) => setState(() => on == true ? _selected.add(item.id) : _selected.remove(item.id)),
                      title: InkWell(
                        onTap: () => _open(item),
                        child: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                        ),
                      ),
                      subtitle: Text(
                        [
                          'Saved ${item.updatedAt.split('T').first}',
                          if (item.owner.isNotEmpty) item.owner,
                        ].join(' - '),
                      ),
                      secondary: IconButton(
                        tooltip: 'Open the saved schedule',
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _open(item),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
