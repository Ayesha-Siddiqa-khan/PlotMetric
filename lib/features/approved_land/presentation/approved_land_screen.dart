import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../export/presentation/table_export_dialog.dart';
import '../../schemes/presentation/scheme_scan_screen.dart';
import '../logic/approved_land.dart';
import '../logic/approved_land_export.dart';
import '../logic/approved_land_repository.dart';

/// Register of approved land sub-divisions (colonies) with their transfer position.
class ApprovedLandScreen extends StatefulWidget {
  const ApprovedLandScreen({super.key, this.isActive = true, this.repository});
  final bool isActive;
  final ApprovedLandRepository? repository;

  @override
  State<ApprovedLandScreen> createState() => _ApprovedLandScreenState();
}

class _ApprovedLandScreenState extends State<ApprovedLandScreen> {
  late final ApprovedLandRepository _repo =
      widget.repository ?? ApprovedLandRepository();
  List<ApprovedLandEntry> _entries = [];
  String _search = '';
  bool _loading = true;
  String? _error;
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  final _selected = <int>{};
  bool _barsReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ApprovedLandScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The tab stays mounted, so refresh when it becomes visible (a scan may have changed a row).
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _repo.all();
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load the approved land register.';
        });
      }
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  /// The chosen rows, or every row currently shown (after the search) when none is chosen.
  List<ApprovedLandEntry> get _exportRows {
    final shown = _entries.where(_matches).toList();
    return _selected.isEmpty ? shown : shown.where((entry) => _selected.contains(entry.id)).toList();
  }

  Future<void> _export() async {
    final rows = _exportRows;
    if (rows.isEmpty) {
      _toast('There are no colonies to export.');
      return;
    }
    await TableExportDialog.show(
      context,
      title: ApprovedLandExport.title,
      subtitle: ApprovedLandExport.subtitle,
      columns: ApprovedLandExport.columns,
      groups: [ApprovedLandExport.group(rows)],
      fileStem: 'Approved_Land',
    );
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _openScan(ApprovedLandEntry entry) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SchemeScanScreen(approved: entry)),
    );
    if (mounted) _load();
  }

  Future<void> _edit(ApprovedLandEntry? original) async {
    final result = await showDialog<ApprovedLandEntry>(
      context: context,
      builder: (_) =>
          _EntryDialog(original: original?.copy() ?? ApprovedLandEntry()),
    );
    if (result == null || !mounted) return;
    try {
      await _repo.save(result);
      await _load();
    } catch (_) {
      if (mounted) _toast('Could not save the entry.');
    }
  }

  Future<void> _delete(ApprovedLandEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          '${entry.name}\n\nThis removes it from the Approved Land register. A scan saved for it stays in Records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || entry.id == null) return;
    await _repo.delete(entry.id!);
    if (mounted) _load();
  }

  bool _matches(ApprovedLandEntry entry) {
    if (_search.isEmpty) return true;
    final haystack = [
      entry.serial?.toString() ?? '',
      entry.name,
      entry.owner,
      entry.mouza,
      entry.totalArea,
    ].join(' ').toLowerCase();
    return haystack.contains(_search);
  }

  Widget _area(String text) {
    if (text.trim().isEmpty) return const Center(child: Text('—'));
    final shownText = LandAreaText.normalize(text);
    final valid =
        LandAreaText.parse(text) != null ||
        text.trim().startsWith('-') &&
            LandAreaText.parse(text.trim().substring(1)) != null;
    return Tooltip(
      message: valid
          ? ''
          : 'Not a valid area (Marla must be below 20, Sarsai below 9). Tap to correct it.',
      child: Center(
        child: Text(
          shownText,
          textAlign: TextAlign.center,
          style: valid
              ? null
              : const TextStyle(
                  color: AppTheme.dangerRed,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ),
    );
  }

  DataCell _cell(ApprovedLandEntry entry, Widget child, {double? width}) =>
      DataCell(
        width == null ? child : SizedBox(width: width, child: child),
        onTap: () => _edit(entry),
      );

  // Column widths are kept narrow so the register stays readable on a phone, where it scrolls sideways.
  static const _wSerial = 40.0,
      _wName = 150.0,
      _wOwner = 170.0,
      _wMouza = 140.0;
  static const _wArea = 104.0, _wActions = 112.0;

  DataColumn _head(String text, double width, {bool center = false}) =>
      DataColumn(
        label: SizedBox(
          width: width,
          child: Text(
            text,
            textAlign: center ? TextAlign.center : TextAlign.start,
          ),
        ),
      );

  /// Horizontal scroll bar pinned to the bottom of the screen, vertical scroll inside it.
  Widget _table(List<ApprovedLandEntry> shown) {
    if (!_barsReady) {
      // Forcing a scroll bar visible before its scroll view exists throws, so wait for the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _horizontal.hasClients && _vertical.hasClients) {
          setState(() => _barsReady = true); }
      });
    }
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: _tableBody(shown),
    );
  }

  Widget _tableBody(List<ApprovedLandEntry> shown) => Scrollbar(
    controller: _horizontal,
    thumbVisibility: _barsReady,
    trackVisibility: _barsReady,
    notificationPredicate: (notification) => notification.depth == 0,
    child: SingleChildScrollView(
      controller: _horizontal,
      scrollDirection: Axis.horizontal,
      child: Scrollbar(
        controller: _vertical,
        thumbVisibility: _barsReady,
        child: SingleChildScrollView(
          controller: _vertical,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DataTable(
            showCheckboxColumn: true,
            onSelectAll: (all) => setState(() {
              if (all == true) {
                _selected.addAll([for (final entry in shown) ?entry.id]);
              } else {
                _selected.removeAll([for (final entry in shown) ?entry.id]);
              }
            }),
            columnSpacing: 10,
            horizontalMargin: 6,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 64,
            headingRowHeight: 64,
            border: TableBorder.all(color: AppTheme.dividerColor),
            columns: [
              _head('Sr.\nNo.', _wSerial),
              _head('Name of\nHousing Scheme', _wName),
              _head('Name of Owners /\nDevelopers', _wOwner),
              _head('Name of Mouza (s)\nAddress / Road', _wMouza),
              _head('Total Area\n(K-M-S)', _wArea, center: true),
              _head(
                'Total Transferable\nArea to MC (K-M-S)',
                _wArea,
                center: true,
              ),
              _head('Transferred\nto MC (K-M-S)', _wArea, center: true),
              _head('Remaining\nTransfer (K-M-S)', _wArea, center: true),
              _head('Mortgage\nDeed (K-M-S)', _wArea, center: true),
              _head('', _wActions),
            ],
            rows: [
              for (final entry in shown)
                DataRow(
                  key: ValueKey(entry.id),
                  selected: _selected.contains(entry.id),
                  onSelectChanged: entry.id == null
                      ? null
                      : (on) => setState(() => on == true ? _selected.add(entry.id!) : _selected.remove(entry.id!)),
                  cells: [
                    _cell(
                      entry,
                      Text(entry.serial?.toString() ?? ''),
                      width: _wSerial,
                    ),
                    DataCell(
                      SizedBox(
                        width: _wName,
                        child: Row(
                          children: [
                            if (entry.schemeId != null)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Tooltip(
                                  message:
                                      'A scanned schedule is saved for this colony. Tap the name to view it.',
                                  child: Icon(
                                    Icons.task_alt,
                                    size: 16,
                                    color: AppTheme.accentTeal,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                entry.name,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.primaryNavy,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () => _openScan(entry),
                    ),
                    _cell(
                      entry,
                      Text(
                        entry.owner,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      width: _wOwner,
                    ),
                    _cell(
                      entry,
                      Text(
                        entry.mouza,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      width: _wMouza,
                    ),
                    _cell(entry, _area(entry.totalArea), width: _wArea),
                    _cell(entry, _area(entry.transferTotal), width: _wArea),
                    _cell(entry, _area(entry.transferred), width: _wArea),
                    _cell(entry, _area(entry.remaining), width: _wArea),
                    _cell(entry, _area(entry.mortgage), width: _wArea),
                    DataCell(
                      SizedBox(
                        width: _wActions,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (tip, icon, action)
                                in <(String, IconData, VoidCallback)>[
                                  (
                                    'Edit',
                                    Icons.edit_outlined,
                                    () => _edit(entry),
                                  ),
                                  (
                                    'Scan area schedule',
                                    Icons.document_scanner_outlined,
                                    () => _openScan(entry),
                                  ),
                                  (
                                    'Delete',
                                    Icons.delete_outline,
                                    () => _delete(entry),
                                  ),
                                ])
                              IconButton(
                                tooltip: tip,
                                onPressed: action,
                                iconSize: 20,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(34, 34),
                                  padding: const EdgeInsets.all(6),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(icon),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final shown = _entries.where(_matches).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approved Land'),
        actions: [
          IconButton(
            tooltip: 'Add colony',
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search by colony, owner, mouza or area',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _edit(null),
                        icon: const Icon(Icons.add),
                        label: const Text('New colony'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _export,
                        icon: const Icon(Icons.ios_share),
                        label: Text(_selected.isEmpty ? 'Export' : 'Export (${_selected.length})'),
                      ),
                      if (_selected.isNotEmpty)
                        TextButton(onPressed: () => setState(_selected.clear), child: const Text('Clear')),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Detail of approved land sub-division, Municipal Committee Chishtian. '
                'Tap a colony name to scan its area schedule. Tap any other cell to edit. '
                'Areas are Kanal-Marla-Sarsai (K-M-S). ${shown.length} of ${_entries.length} shown.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : shown.isEmpty
                  ? const Center(child: Text('No colonies found.'))
                  : _table(shown),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.original});
  final ApprovedLandEntry original;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final ApprovedLandEntry _start = widget.original.copy();
  late final _serial = TextEditingController(
    text: _start.serial?.toString() ?? '',
  );
  late final _name = TextEditingController(text: _start.name);
  late final _owner = TextEditingController(text: _start.owner);
  late final _mouza = TextEditingController(text: _start.mouza);
  late final _total = TextEditingController(text: _start.totalArea);
  late final _transferTotal = TextEditingController(text: _start.transferTotal);
  late final _transferred = TextEditingController(text: _start.transferred);
  late final _remaining = TextEditingController(text: _start.remaining);
  late final _mortgage = TextEditingController(text: _start.mortgage);
  late final _note = TextEditingController(text: _start.note);
  String? _problem;

  @override
  void dispose() {
    for (final c in [
      _serial,
      _name,
      _owner,
      _mouza,
      _total,
      _transferTotal,
      _transferred,
      _remaining,
      _mortgage,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    int lines = 1,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  void _apply() {
    if (_name.text.trim().isEmpty) {
      setState(() => _problem = 'Enter the name of the housing scheme.');
      return;
    }
    final serialText = _serial.text.trim();
    final serial = int.tryParse(serialText);
    if (serialText.isNotEmpty && serial == null) {
      setState(() => _problem = 'Sr.No must be a number.');
      return;
    }
    final entry = _start
      ..serial = serial
      ..name = _name.text.trim()
      ..owner = _owner.text.trim()
      ..mouza = _mouza.text.trim()
      ..totalArea = LandAreaText.normalize(_total.text)
      ..transferTotal = LandAreaText.normalize(_transferTotal.text)
      ..transferred = LandAreaText.normalize(_transferred.text)
      ..remaining = LandAreaText.normalize(_remaining.text)
      ..mortgage = LandAreaText.normalize(_mortgage.text)
      ..note = _note.text.trim();
    final changed =
        widget.original.transferTotal != entry.transferTotal ||
        widget.original.transferred != entry.transferred;
    final computed = ApprovedLandEntry.computeRemaining(
      entry.transferTotal,
      entry.transferred,
    );
    // Remaining follows the other two unless the user typed it themselves.
    if (computed.isNotEmpty &&
        (entry.remaining.isEmpty ||
            (changed && entry.remaining == widget.original.remaining))) {
      entry.remaining = computed;
    }
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.original.id == null ? 'Add colony' : 'Edit colony'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('Sr.No', _serial, type: TextInputType.number),
            _field('Name of Housing Scheme', _name),
            _field('Name of Owners / Developers', _owner, lines: 2),
            _field('Name of Mouza (s) / Address / Road', _mouza),
            _field('Total Area', _total, hint: 'e.g. 91K-16M-0S'),
            _field(
              'Total Transferable Area to MC',
              _transferTotal,
              hint: 'K-M-S (filled when you scan the schedule)',
            ),
            _field(
              'Transferred to MC (Transfer Deed)',
              _transferred,
              hint: 'K-M-S',
            ),
            _field(
              'Remaining Transfer',
              _remaining,
              hint: 'Calculated from the two above, or type it',
            ),
            _field('Mortgage Deed', _mortgage, hint: 'K-M-S'),
            _field('Note', _note, lines: 2),
            const Text(
              'Areas can be typed as 91K-16M-0S, 91K 16M, 91K or 5K 05M 5S. They are stored as K-M-S. '
              'Text that is not a valid area is kept as typed and shown in red.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _problem!,
                  style: const TextStyle(color: AppTheme.dangerRed),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Apply')),
    ],
  );
}
