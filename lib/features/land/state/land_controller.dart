import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/land_units.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../data/models/calculation.dart';
import '../../../data/models/measurement_entry.dart';
import '../../../data/repositories/calculation_repository.dart';
import '../logic/land_math.dart';
import 'land_row_model.dart';

final calculationRepositoryProvider = Provider<CalculationRepository>((ref) {
  return CalculationRepository();
});

final landControllerProvider = Provider<LandController>((ref) {
  final repo = ref.watch(calculationRepositoryProvider);
  final controller = LandController(repository: repo);
  ref.onDispose(controller.dispose);
  return controller;
});

class LandController extends ChangeNotifier {
  final CalculationRepository repository;

  int? _currentCalculationId;
  String _title = '';
  DateTime _calculationDate = DateTime.now();
  TimeOfDay _calculationTime = TimeOfDay.now();
  String _createdAtUtc = '';

  final List<LandRowModel> _rows = [];
  bool _isDirty = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<String> _purposeSuggestions = List.from(LandUnits.defaultPurposes);

  LandController({required this.repository}) {
    _initNewWorksheet(notify: false);
    _refreshPurposes();
  }

  // Getters
  int? get currentCalculationId => _currentCalculationId;
  String get title => _title;
  DateTime get calculationDate => _calculationDate;
  TimeOfDay get calculationTime => _calculationTime;
  List<LandRowModel> get rows => List.unmodifiable(_rows);
  bool get isDirty => _isDirty;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get purposeSuggestions => _purposeSuggestions;
  bool get isEditingExisting => _currentCalculationId != null;

  String get displayDate => DateTimeFormatters.formatDisplayDate(_calculationDate);
  String get displayTime => DateTimeFormatters.formatDisplayTime(
        DateTime(2000, 1, 1, _calculationTime.hour, _calculationTime.minute),
      );

  LandWorksheetSummary get summary {
    final summaryRows = _rows.map((r) {
      return (isSubtract: r.isSubtract, centiSarsai: r.centiSarsai);
    }).toList();
    return LandMath.computeSummary(summaryRows);
  }

  bool get hasErrors {
    return _rows.any((r) => r.hasError);
  }

  Future<void> _refreshPurposes() async {
    try {
      final list = await repository.getDistinctPurposes();
      _purposeSuggestions = list;
      notifyListeners();
    } catch (_) {
      // Fallback already contains defaultPurposes
    }
  }

  void _initNewWorksheet({bool notify = true}) {
    _disposeAllRows();
    _currentCalculationId = null;
    _title = '';
    _calculationDate = DateTime.now();
    _calculationTime = TimeOfDay.now();
    _createdAtUtc = '';
    _isDirty = false;
    _errorMessage = null;

    final initialRow = LandRowModel(
      keyId: _generateKey(),
      operation: EntryOperation.add,
      purpose: 'Nil',
      kanal: 0,
      marla: 0,
      sarsaiCenti: 0,
    );
    _rows.add(initialRow);

    if (notify) {
      notifyListeners();
    }
  }

  String _generateKey() {
    return '${DateTime.now().microsecondsSinceEpoch}_${_rows.length}';
  }

  void setTitle(String newTitle) {
    if (_title != newTitle) {
      _title = newTitle;
      _isDirty = true;
      notifyListeners();
    }
  }

  void setDate(DateTime date) {
    _calculationDate = date;
    _isDirty = true;
    notifyListeners();
  }

  void setTime(TimeOfDay time) {
    _calculationTime = time;
    _isDirty = true;
    notifyListeners();
  }

  void addRow({bool isSubtract = false}) {
    final newRow = LandRowModel(
      keyId: _generateKey(),
      operation: isSubtract ? EntryOperation.subtract : EntryOperation.add,
      purpose: 'Nil',
      kanal: 0,
      marla: 0,
      sarsaiCenti: 0,
    );
    _rows.add(newRow);
    _isDirty = true;
    notifyListeners();

    // Focus Purpose / Amenity on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newRow.purposeFocus.requestFocus();
    });
  }

  void appendCalculatedPlot({
    required String purpose,
    required int kanal,
    required int marla,
    required int sarsaiCenti,
    bool isSubtract = false,
  }) {
    final newRow = LandRowModel(
      keyId: _generateKey(),
      operation: isSubtract ? EntryOperation.subtract : EntryOperation.add,
      purpose: purpose,
      kanal: kanal,
      marla: marla,
      sarsaiCenti: sarsaiCenti,
    );
    _rows.add(newRow);
    _isDirty = true;
    notifyListeners();
  }

  void removeRow(int index) {
    if (index <= 0 || index >= _rows.length) return;
    final removed = _rows.removeAt(index);
    removed.dispose();
    _isDirty = true;
    notifyListeners();
  }

  void toggleRowOperation(int index) {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    row.operation = row.isSubtract ? EntryOperation.add : EntryOperation.subtract;
    _isDirty = true;
    notifyListeners();
  }

  void setRowPurpose(int index, String newPurpose) {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index];
    final trimmed = newPurpose.trim();
    final finalPurpose = trimmed.isEmpty ? 'Nil' : trimmed;
    row.purpose = finalPurpose;
    if (row.purposeController.text != finalPurpose) {
      row.purposeController.text = finalPurpose;
    }
    _isDirty = true;
    notifyListeners();
  }

  void updateRowValues(int index) {
    if (index < 0 || index >= _rows.length) return;
    _rows[index].validate();
    _isDirty = true;
    notifyListeners();
  }

  void newWorksheet() {
    _initNewWorksheet(notify: true);
    // Focus first row Kanal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rows.isNotEmpty) {
        _rows.first.kanalFocus.requestFocus();
      }
    });
  }

  /// Alias for clearing and starting a new worksheet
  void clearToNew() => newWorksheet();

  void loadCalculation(Calculation calc) {
    _disposeAllRows();
    _currentCalculationId = calc.id;
    _title = calc.title;

    final parsedDate = DateTime.tryParse(calc.calculationDate);
    _calculationDate = parsedDate ?? DateTime.now();

    final timeParts = calc.calculationTime.split(':');
    if (timeParts.length == 2) {
      final hour = int.tryParse(timeParts[0]) ?? 12;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      _calculationTime = TimeOfDay(hour: hour, minute: minute);
    } else {
      _calculationTime = TimeOfDay.now();
    }

    _createdAtUtc = calc.createdAtUtc;
    _isDirty = false;
    _errorMessage = null;

    if (calc.entries.isEmpty) {
      _rows.add(LandRowModel(
        keyId: _generateKey(),
        operation: EntryOperation.add,
        purpose: 'Nil',
        kanal: 0,
        marla: 0,
        sarsaiCenti: 0,
      ));
    } else {
      for (int i = 0; i < calc.entries.length; i++) {
        final entry = calc.entries[i];
        _rows.add(LandRowModel(
          keyId: '${calc.id}_entry_${entry.id ?? i}',
          dbId: entry.id,
          operation: entry.operation,
          purpose: entry.purpose,
          kanal: entry.kanal,
          marla: entry.marla,
          sarsaiCenti: entry.sarsaiCenti,
        ));
      }
    }

    notifyListeners();
  }

  void importMeasurements({
    String? title,
    required List<MeasurementEntry> entries,
  }) {
    _disposeAllRows();
    _currentCalculationId = null;
    if (title != null && title.trim().isNotEmpty) {
      _title = title.trim();
    }
    _calculationDate = DateTime.now();
    _calculationTime = TimeOfDay.now();
    _createdAtUtc = '';
    _isDirty = true;
    _errorMessage = null;

    if (entries.isEmpty) {
      _rows.add(LandRowModel(
        keyId: _generateKey(),
        operation: EntryOperation.add,
        purpose: 'Nil',
        kanal: 0,
        marla: 0,
        sarsaiCenti: 0,
      ));
    } else {
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        _rows.add(LandRowModel(
          keyId: 'imported_${DateTime.now().microsecondsSinceEpoch}_$i',
          operation: entry.operation,
          purpose: entry.purpose,
          kanal: entry.kanal,
          marla: entry.marla,
          sarsaiCenti: entry.sarsaiCenti,
        ));
      }
    }

    notifyListeners();
  }

  /// Converts current worksheet state to a Calculation object for export or saving
  Calculation toCalculation() {
    final trimmedTitle = _title.trim().isEmpty ? 'Colony Land Calculation' : _title.trim();
    final isoDate = DateTimeFormatters.formatStorageDate(_calculationDate);
    final hourStr = _calculationTime.hour.toString().padLeft(2, '0');
    final minuteStr = _calculationTime.minute.toString().padLeft(2, '0');
    final storageTime = '$hourStr:$minuteStr';

    final calculationEntries = <MeasurementEntry>[];
    for (int i = 0; i < _rows.length; i++) {
      calculationEntries.add(_rows[i].toMeasurementEntry(sortOrder: i));
    }

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    return Calculation(
      id: _currentCalculationId,
      title: trimmedTitle,
      calculationDate: isoDate,
      calculationTime: storageTime,
      createdAtUtc: _createdAtUtc.isNotEmpty ? _createdAtUtc : nowUtc,
      updatedAtUtc: nowUtc,
      entries: calculationEntries,
    );
  }

  /// Sets up a standard Housing Scheme / Colony land breakdown template
  void loadColonyDeductionTemplate({
    String title = 'Colony Planning Scheme',
    int kanal = 95,
    int marla = 20,
    int sarsaiCenti = 800,
  }) {
    _disposeAllRows();
    _currentCalculationId = null;
    _title = title;
    _calculationDate = DateTime.now();
    _calculationTime = TimeOfDay.now();
    _createdAtUtc = '';
    _isDirty = true;
    _errorMessage = null;

    // Row 0: Gross Colony Area
    _rows.add(LandRowModel(
      keyId: _generateKey(),
      operation: EntryOperation.add,
      purpose: 'Total Colony Area',
      kanal: kanal,
      marla: marla,
      sarsaiCenti: sarsaiCenti,
    ));

    // Standard deduction rows
    final deductionPurposes = [
      'Roads',
      'Central Mosque',
      'Play Ground / Parks',
      'Graveyard',
      'Sewerage & Disposal',
      'Dispensary / Clinic',
      'Commercial / Public Buildings',
    ];

    for (final purpose in deductionPurposes) {
      _rows.add(LandRowModel(
        keyId: _generateKey(),
        operation: EntryOperation.subtract,
        purpose: purpose,
        kanal: 0,
        marla: 0,
        sarsaiCenti: 0,
      ));
    }

    notifyListeners();
  }

  List<int> get runningBalances {
    final summaryRows = _rows.map((r) {
      return (isSubtract: r.isSubtract, centiSarsai: r.centiSarsai);
    }).toList();
    return LandMath.computeRunningBalances(summaryRows);
  }

  double getRowPercentageOfGross(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _rows.length) return 0.0;
    final gross = summary.totalAddedUnits;
    if (gross <= 0) return 0.0;
    return (_rows[rowIndex].centiSarsai / gross) * 100.0;
  }

  Future<bool> saveCalculation({bool saveAsNew = false}) async {
    final trimmedTitle = _title.trim();
    final effectiveTitle = trimmedTitle.isNotEmpty
        ? trimmedTitle
        : 'Calculation ${DateTimeFormatters.formatDisplayDate(_calculationDate)} ${DateTimeFormatters.formatDisplayTime(_calculationTime)}';

    if (hasErrors) {
      _errorMessage = 'Please fix input errors before saving.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isoDate = DateTimeFormatters.formatStorageDate(_calculationDate);
      final hourStr = _calculationTime.hour.toString().padLeft(2, '0');
      final minuteStr = _calculationTime.minute.toString().padLeft(2, '0');
      final storageTime = '$hourStr:$minuteStr';

      final calculationEntries = <MeasurementEntry>[];
      for (int i = 0; i < _rows.length; i++) {
        calculationEntries.add(_rows[i].toMeasurementEntry(sortOrder: i));
      }

      final nowUtc = DateTime.now().toUtc().toIso8601String();

      if (_currentCalculationId != null && !saveAsNew) {
        // Update existing atomically
        final updatedCalc = Calculation(
          id: _currentCalculationId,
          title: effectiveTitle,
          calculationDate: isoDate,
          calculationTime: storageTime,
          createdAtUtc: _createdAtUtc.isNotEmpty ? _createdAtUtc : nowUtc,
          updatedAtUtc: nowUtc,
          entries: calculationEntries,
        );
        await repository.updateCalculation(updatedCalc);
      } else {
        // Insert new
        final newCalc = Calculation(
          title: effectiveTitle,
          calculationDate: isoDate,
          calculationTime: storageTime,
          createdAtUtc: nowUtc,
          updatedAtUtc: nowUtc,
          entries: calculationEntries,
        );
        final newId = await repository.insertCalculation(newCalc);
        _currentCalculationId = newId;
        _createdAtUtc = nowUtc;
      }

      _title = effectiveTitle;
      _isDirty = false;
      _isLoading = false;
      await _refreshPurposes();
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Database save failed: $e';
      notifyListeners();
      return false;
    }
  }

  String buildSummaryPlainText() {
    final buffer = StringBuffer();
    buffer.writeln('PlotMetric — Land Measurement Summary');
    buffer.writeln('====================================');
    buffer.writeln('Title: ${_title.isEmpty ? "(Untitled)" : _title}');
    buffer.writeln('Date: $displayDate   Time: $displayTime');
    buffer.writeln('------------------------------------');
    buffer.writeln('MEASUREMENTS:');

    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final sign = r.isSubtract ? '-' : '+';
      buffer.writeln(
        '${i + 1}. [$sign] ${r.purpose}: ${r.kanal} Kanal, ${r.marla} Marla, ${r.sarsaiController.text} Sarsai = ${r.sqFtFormatted} sq ft',
      );
    }

    buffer.writeln('------------------------------------');
    final s = summary;
    buffer.writeln('Total Added:    ${s.totalAddedSqFtFormatted} sq ft');
    buffer.writeln('Total Deducted: ${s.totalDeductedSqFtFormatted} sq ft');
    buffer.writeln('Net Area:       ${s.netCompositeArea.toDisplayString()}');
    buffer.writeln('Net Sq Ft:      ${s.netSqFtFormatted} sq ft');
    buffer.writeln('====================================');
    return buffer.toString();
  }

  void _disposeAllRows() {
    for (final r in _rows) {
      r.dispose();
    }
    _rows.clear();
  }

  @override
  void dispose() {
    _disposeAllRows();
    super.dispose();
  }
}
