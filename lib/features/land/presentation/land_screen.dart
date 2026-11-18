import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/number_formatters.dart';
import '../state/land_controller.dart';
import 'widgets/land_summary.dart';
import 'widgets/measurement_sheet.dart';

class LandScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToRecords;

  const LandScreen({super.key, this.onNavigateToRecords});

  @override
  ConsumerState<LandScreen> createState() => _LandScreenState();
}

class _LandScreenState extends ConsumerState<LandScreen> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(landControllerProvider);
    _titleController = TextEditingController(text: controller.title);

    // Initial autofocus on first row's Kanal after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.rows.isNotEmpty) {
        controller.rows.first.kanalFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<bool> _handlePopScope() async {
    final controller = ref.read(landControllerProvider);
    if (!controller.isDirty) return true;

    final shouldLeave = await _showUnsavedChangesDialog();
    return shouldLeave;
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final controller = ref.read(landControllerProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes in this calculation. Would you like to save before proceeding?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerRed),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      final saved = await controller.saveCalculation();
      return saved;
    } else if (result == 'discard') {
      return true;
    }
    return false; // Cancel
  }

  Future<void> _pickDate() async {
    final controller = ref.read(landControllerProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.calculationDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryNavy,
              onPrimary: Colors.white,
              onSurface: AppTheme.primaryNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.setDate(picked);
    }
  }

  Future<void> _pickTime() async {
    final controller = ref.read(landControllerProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: controller.calculationTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryNavy,
              onPrimary: Colors.white,
              onSurface: AppTheme.primaryNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.setTime(picked);
    }
  }

  void _onNewPressed() async {
    final controller = ref.read(landControllerProvider);
    if (controller.isDirty) {
      final proceed = await _showUnsavedChangesDialog();
      if (!proceed) return;
    }
    controller.newWorksheet();
    _titleController.text = '';
  }

  void _onSavePressed({bool saveAsNew = false}) async {
    final controller = ref.read(landControllerProvider);
    controller.setTitle(_titleController.text);

    final success = await controller.saveCalculation(saveAsNew: saveAsNew);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveAsNew
                ? 'Calculation duplicated as new record successfully!'
                : 'Calculation saved successfully!',
          ),
          backgroundColor: AppTheme.accentTeal,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage!),
          backgroundColor: AppTheme.dangerRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onCopySummaryPressed() {
    final controller = ref.read(landControllerProvider);
    controller.setTitle(_titleController.text);
    final text = controller.buildSummaryPlainText();

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Land summary copied to clipboard!'),
        backgroundColor: AppTheme.primaryNavy,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showColonySchemeDialog() {
    final titleCtrl = TextEditingController(text: 'Housing Scheme Plan');
    final kanalCtrl = TextEditingController(text: '95');
    final marlaCtrl = TextEditingController(text: '20');
    final sarsaiCtrl = TextEditingController(text: '8');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.apartment, color: AppTheme.accentTeal),
            SizedBox(width: 8),
            Text('Colony Planning Scheme'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the Gross Colony Area (کل رقبہ). This sets up the total area and pre-populates standard deduction lines for Roads, Mosque, Parks, Graveyard, Sewerage, Dispensary, etc.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Scheme Title'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: kanalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Kanal (کنال)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: marlaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Marla (مرلہ)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: sarsaiCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Sarsai (سرسائی)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final k = int.tryParse(kanalCtrl.text) ?? 0;
              final m = int.tryParse(marlaCtrl.text) ?? 0;
              final s = NumberFormatters.parseSarsaiToCenti(sarsaiCtrl.text) ?? 0;

              ref.read(landControllerProvider).loadColonyDeductionTemplate(
                    title: titleCtrl.text,
                    kanal: k,
                    marla: m,
                    sarsaiCenti: s,
                  );
              _titleController.text = titleCtrl.text;
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Colony scheme template created! Enter measurements for roads, mosque, parks, etc.'),
                  backgroundColor: AppTheme.accentTeal,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.maps_home_work_outlined, size: 18),
            label: const Text('Create Scheme Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(landControllerProvider);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Sync external title change (e.g. from loading record)
        if (_titleController.text != controller.title && !controller.isDirty) {
          _titleController.text = controller.title;
        }

        return PopScope(
          canPop: !controller.isDirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _handlePopScope();
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
        appBar: AppBar(
          title: const Text('PlotMetric'),
          actions: [
            TextButton.icon(
              onPressed: _showColonySchemeDialog,
              icon: const Icon(Icons.apartment, color: Colors.white, size: 18),
              label: const Text(
                'Colony Scheme',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.onNavigateToRecords != null)
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Saved Records',
                onPressed: widget.onNavigateToRecords,
              ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(24),
            child: Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Land Calculator',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card: Title, Date, Time & Conversion Reference
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title Input
                          TextFormField(
                            controller: _titleController,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: 'Calculation Title *',
                              hintText: 'e.g. Ittefaq City',
                              counterText: '',
                              prefixIcon: const Icon(Icons.label_outline, size: 20),
                              suffixIcon: controller.isEditingExisting
                                  ? const Tooltip(
                                      message: 'Editing existing saved record',
                                      child: Icon(Icons.edit_note, color: AppTheme.accentTeal),
                                    )
                                  : null,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            onChanged: (val) => controller.setTitle(val),
                          ),
                          const SizedBox(height: 10),
                          // Date & Time pickers
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(6),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Date',
                                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                    child: Text(
                                      controller.displayDate,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickTime,
                                  borderRadius: BorderRadius.circular(6),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Time',
                                      prefixIcon: Icon(Icons.access_time, size: 18),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                    child: Text(
                                      controller.displayTime,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Fixed conversion reference banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '1 Kanal = 20 Marla · 1 Marla = 9 Sarsai · 1 Marla = 272.25 sq ft',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Single Continuous Worksheet Panel
                    MeasurementSheetWidget(
                      rows: controller.rows,
                      purposeSuggestions: controller.purposeSuggestions,
                      onToggleSign: (i) => controller.toggleRowOperation(i),
                      onPurposeChanged: (i, p) => controller.setRowPurpose(i, p),
                      onValuesChanged: (i) => controller.updateRowValues(i),
                      onDeleteRow: (i) => controller.removeRow(i),
                      onAddRow: () => controller.addRow(isSubtract: false),
                      onDeductRow: () => controller.addRow(isSubtract: true),
                      isNarrow: isNarrow,
                      runningBalances: controller.runningBalances,
                      grossCenti: controller.summary.totalAddedUnits,
                    ),
                    const SizedBox(height: 12),
                    // Summary Section
                    LandSummaryWidget(summary: controller.summary),
                    const SizedBox(height: 14),
                    // Footer Actions: Save / Save as New / New / Copy Summary
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: controller.isLoading ? null : () => _onSavePressed(saveAsNew: false),
                          icon: controller.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: Text(
                            controller.isEditingExisting ? 'Save Changes' : 'Save',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        if (controller.isEditingExisting)
                          OutlinedButton.icon(
                            onPressed: controller.isLoading ? null : () => _onSavePressed(saveAsNew: true),
                            icon: const Icon(Icons.copy_all, size: 18, color: AppTheme.accentTeal),
                            label: const Text(
                              'Save as New',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.accentTeal),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _onNewPressed,
                          icon: const Icon(Icons.add_box_outlined, size: 18, color: AppTheme.primaryNavy),
                          label: const Text(
                            'New',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primaryNavy),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _onCopySummaryPressed,
                          icon: const Icon(Icons.copy, size: 18, color: AppTheme.textMuted),
                          label: const Text(
                            'Copy Summary',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.dividerColor),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);
  }
}
