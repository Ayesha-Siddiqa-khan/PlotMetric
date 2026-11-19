import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/calculation.dart';
import '../../../data/models/measurement_entry.dart';
import '../../export/presentation/calculation_export_dialog.dart';
import '../../land/state/land_controller.dart';
import '../logic/dimension_math.dart';

class DimensionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToLand;
  final bool isActive;

  const DimensionScreen({
    super.key,
    this.onNavigateToLand,
    this.isActive = false,
  });

  @override
  ConsumerState<DimensionScreen> createState() => _DimensionScreenState();
}

class _DimensionScreenState extends ConsumerState<DimensionScreen> {
  int _selectedMode = 0; // 0: Dimensions (Length x Width), 1: Direct Sq Ft

  // Focus Nodes for auto-focus and auto-select
  final FocusNode _widthFeetFocus = FocusNode();
  final FocusNode _widthInchesFocus = FocusNode();
  final FocusNode _lengthFeetFocus = FocusNode();
  final FocusNode _lengthInchesFocus = FocusNode();
  final FocusNode _plotLabelFocus = FocusNode();

  final FocusNode _directSqFtFocus = FocusNode();
  final FocusNode _directLabelFocus = FocusNode();

  // Mode 0 Controllers (Feet & Inches)
  final TextEditingController _widthFeetCtrl = TextEditingController(text: '10');
  final TextEditingController _widthInchesCtrl = TextEditingController(text: '5');
  final TextEditingController _lengthFeetCtrl = TextEditingController(text: '70');
  final TextEditingController _lengthInchesCtrl = TextEditingController(text: '0');
  final TextEditingController _plotLabelCtrl = TextEditingController(text: 'Plot (10\' - 5" x 70\' - 0")');

  // Mode 1 Controller (Direct Sq Ft)
  final TextEditingController _directSqFtCtrl = TextEditingController(text: '729.17');
  final TextEditingController _directLabelCtrl = TextEditingController(text: 'Custom Plot Area');

  // Square Yards Checkbox (Default false / unchecked as requested)
  bool _includeSqYards = false;
  bool _userEditedPlotLabel = false;

  @override
  void initState() {
    super.initState();
    _attachFocusListeners();

    // Autofocus Plot Width / Front (Feet) by default after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoFocus();
    });
  }

  @override
  void didUpdateWidget(covariant DimensionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerAutoFocus();
      });
    }
  }

  void _triggerAutoFocus() {
    if (_selectedMode == 0) {
      _widthFeetFocus.requestFocus();
      if (_widthFeetCtrl.text.isNotEmpty) {
        _widthFeetCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _widthFeetCtrl.text.length,
        );
      }
    } else {
      _directSqFtFocus.requestFocus();
      if (_directSqFtCtrl.text.isNotEmpty) {
        _directSqFtCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _directSqFtCtrl.text.length,
        );
      }
    }
  }

  void _attachFocusListeners() {
    _setupFieldAutoSelect(_widthFeetFocus, _widthFeetCtrl, '10');
    _setupFieldAutoSelect(_widthInchesFocus, _widthInchesCtrl, '5');
    _setupFieldAutoSelect(_lengthFeetFocus, _lengthFeetCtrl, '70');
    _setupFieldAutoSelect(_lengthInchesFocus, _lengthInchesCtrl, '0');
    _setupFieldAutoSelect(_directSqFtFocus, _directSqFtCtrl, '729.17');
  }

  void _setupFieldAutoSelect(FocusNode focusNode, TextEditingController controller, String defaultVal) {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        if (controller.text == defaultVal ||
            controller.text == '0' ||
            controller.text == '0.0') {
          controller.clear();
          _onDimensionsChanged();
        } else {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      }
    });
  }

  void _handleFieldTap(TextEditingController controller, String defaultVal) {
    if (controller.text == defaultVal ||
        controller.text == '0' ||
        controller.text == '0.0' ||
        controller.text.isEmpty) {
      controller.clear();
      _onDimensionsChanged();
    } else {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _widthFeetFocus.dispose();
    _widthInchesFocus.dispose();
    _lengthFeetFocus.dispose();
    _lengthInchesFocus.dispose();
    _plotLabelFocus.dispose();
    _directSqFtFocus.dispose();
    _directLabelFocus.dispose();

    _widthFeetCtrl.dispose();
    _widthInchesCtrl.dispose();
    _lengthFeetCtrl.dispose();
    _lengthInchesCtrl.dispose();
    _plotLabelCtrl.dispose();
    _directSqFtCtrl.dispose();
    _directLabelCtrl.dispose();
    super.dispose();
  }

  DimensionCalculationResult get _dimensionResult {
    final wFeet = int.tryParse(_widthFeetCtrl.text.trim()) ?? 0;
    final wInches = double.tryParse(_widthInchesCtrl.text.trim()) ?? 0.0;
    final lFeet = int.tryParse(_lengthFeetCtrl.text.trim()) ?? 0;
    final lInches = double.tryParse(_lengthInchesCtrl.text.trim()) ?? 0.0;

    return DimensionMath.calculatePlotArea(
      widthFeet: wFeet,
      widthInches: wInches,
      lengthFeet: lFeet,
      lengthInches: lInches,
    );
  }

  DimensionCalculationResult get _directSqFtResult {
    final sqFt = double.tryParse(_directSqFtCtrl.text.trim()) ?? 0.0;
    return DimensionMath.fromSquareFeet(sqFt);
  }

  void _onDimensionsChanged() {
    if (!_userEditedPlotLabel) {
      final wF = _widthFeetCtrl.text.trim();
      final wI = _widthInchesCtrl.text.trim();
      final lF = _lengthFeetCtrl.text.trim();
      final lI = _lengthInchesCtrl.text.trim();

      if (wF.isEmpty && wI.isEmpty && lF.isEmpty && lI.isEmpty) {
        _plotLabelCtrl.text = '';
      } else {
        final dispWF = wF.isEmpty ? '0' : wF;
        final dispWI = wI.isEmpty ? '0' : wI;
        final dispLF = lF.isEmpty ? '0' : lF;
        final dispLI = lI.isEmpty ? '0' : lI;
        _plotLabelCtrl.text = 'Plot ($dispWF\' - $dispWI" x $dispLF\' - $dispLI")';
      }
    }
    setState(() {});
  }

  void _resetToNew() {
    setState(() {
      _widthFeetCtrl.clear();
      _widthInchesCtrl.clear();
      _lengthFeetCtrl.clear();
      _lengthInchesCtrl.clear();
      _plotLabelCtrl.clear();
      _directSqFtCtrl.clear();
      _directLabelCtrl.clear();
      _includeSqYards = false;
      _userEditedPlotLabel = false;
    });

    if (_selectedMode == 0) {
      _widthFeetFocus.requestFocus();
    } else {
      _directSqFtFocus.requestFocus();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All fields reset. Ready for new plot entry!'),
        backgroundColor: AppTheme.accentTeal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addToWorksheet({required bool isDimensionsMode}) {
    final result = isDimensionsMode ? _dimensionResult : _directSqFtResult;
    final baseLabel = isDimensionsMode
        ? (_plotLabelCtrl.text.trim().isEmpty ? 'Plot Dimension' : _plotLabelCtrl.text.trim())
        : (_directLabelCtrl.text.trim().isEmpty ? 'Square Feet Entry' : _directLabelCtrl.text.trim());

    final finalLabel = _includeSqYards
        ? '$baseLabel (${result.squareYardsFormatted} Sq Yds)'
        : baseLabel;

    final landCtrl = ref.read(landControllerProvider);
    landCtrl.appendCalculatedPlot(
      purpose: finalLabel,
      kanal: result.compositeArea.kanal,
      marla: result.compositeArea.marla,
      sarsaiCenti: result.compositeArea.sarsaiCenti,
      isSubtract: false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$finalLabel" (${result.compositeArea.toDisplayString()}) to Land Worksheet!'),
        backgroundColor: AppTheme.accentTeal,
        action: SnackBarAction(
          label: 'View Sheet',
          textColor: Colors.white,
          onPressed: () {
            if (widget.onNavigateToLand != null) {
              widget.onNavigateToLand!();
            }
          },
        ),
      ),
    );
  }

  void _openExportDialog({required bool isDimensionsMode}) {
    final result = isDimensionsMode ? _dimensionResult : _directSqFtResult;
    final baseLabel = isDimensionsMode
        ? (_plotLabelCtrl.text.trim().isEmpty ? 'Plot Dimension' : _plotLabelCtrl.text.trim())
        : (_directLabelCtrl.text.trim().isEmpty ? 'Square Feet Entry' : _directLabelCtrl.text.trim());

    final purpose = _includeSqYards
        ? '$baseLabel (${result.squareYardsFormatted} Sq Yds)'
        : baseLabel;

    final now = DateTime.now();
    final dateIso = now.toIso8601String().split('T').first;
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final calculation = Calculation(
      title: baseLabel,
      calculationDate: dateIso,
      calculationTime: timeStr,
      createdAtUtc: now.toUtc().toIso8601String(),
      updatedAtUtc: now.toUtc().toIso8601String(),
      entries: [
        MeasurementEntry(
          sortOrder: 0,
          purpose: purpose,
          operation: EntryOperation.add,
          kanal: result.compositeArea.kanal,
          marla: result.compositeArea.marla,
          sarsaiCenti: result.compositeArea.sarsaiCenti,
        ),
      ],
    );

    CalculationExportDialog.show(context, calculation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plot Dimensions & Converter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Plot / Reset (نیا اندراج)',
            onPressed: _resetToNew,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export & Print (ایکسپورٹ اور پرنٹ)',
            onPressed: () => _openExportDialog(isDimensionsMode: _selectedMode == 0),
          ),
          if (widget.onNavigateToLand != null)
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'View Land Worksheet',
              onPressed: widget.onNavigateToLand,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mode Selector Tabs
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.architecture),
                        label: Text('Length × Width (Ft/In)'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.swap_horiz),
                        label: Text('Direct Sq Ft to Marla'),
                      ),
                    ],
                    selected: {_selectedMode},
                    onSelectionChanged: (val) {
                      setState(() {
                        _selectedMode = val.first;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_selectedMode == 0) {
                          _widthFeetFocus.requestFocus();
                          if (_widthFeetCtrl.text.isNotEmpty) {
                            _widthFeetCtrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _widthFeetCtrl.text.length,
                            );
                          }
                        } else {
                          _directSqFtFocus.requestFocus();
                          if (_directSqFtCtrl.text.isNotEmpty) {
                            _directSqFtCtrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _directSqFtCtrl.text.length,
                            );
                          }
                        }
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.accentTeal;
                        }
                        return Colors.white;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return AppTheme.primaryNavy;
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_selectedMode == 0)
                    _buildDimensionsMode()
                  else
                    _buildDirectSqFtMode(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mode 0: Length x Width (Feet & Inches)
  Widget _buildDimensionsMode() {
    final result = _dimensionResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Input Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten, color: AppTheme.primaryNavy, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Building Drawing / Site Plan Inputs',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _resetToNew,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('New / Clear', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentTeal,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter plot width and length from blueprint or site plan in Feet and Inches.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              // Width Inputs (چوڑائی)
              const Text(
                'Plot Width / Front (چوڑائی):',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _widthFeetCtrl,
                      focusNode: _widthFeetFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Feet (فٹ)',
                        hintText: '0',
                        suffixText: 'ft',
                      ),
                      onTap: () => _handleFieldTap(_widthFeetCtrl, '10'),
                      onChanged: (_) => _onDimensionsChanged(),
                      onFieldSubmitted: (_) => _widthInchesFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _widthInchesCtrl,
                      focusNode: _widthInchesFocus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Inches (انچ)',
                        hintText: '0',
                        suffixText: 'in',
                      ),
                      onTap: () => _handleFieldTap(_widthInchesCtrl, '5'),
                      onChanged: (_) => _onDimensionsChanged(),
                      onFieldSubmitted: (_) => _lengthFeetFocus.requestFocus(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Length Inputs (لمبائی)
              const Text(
                'Plot Length / Depth (لمبائی):',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _lengthFeetCtrl,
                      focusNode: _lengthFeetFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Feet (فٹ)',
                        hintText: '0',
                        suffixText: 'ft',
                      ),
                      onTap: () => _handleFieldTap(_lengthFeetCtrl, '70'),
                      onChanged: (_) => _onDimensionsChanged(),
                      onFieldSubmitted: (_) => _lengthInchesFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _lengthInchesCtrl,
                      focusNode: _lengthInchesFocus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Inches (انچ)',
                        hintText: '0',
                        suffixText: 'in',
                      ),
                      onTap: () => _handleFieldTap(_lengthInchesCtrl, '0'),
                      onChanged: (_) => _onDimensionsChanged(),
                      onFieldSubmitted: (_) => _plotLabelFocus.requestFocus(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Plot Label Field
              TextFormField(
                controller: _plotLabelCtrl,
                focusNode: _plotLabelFocus,
                decoration: const InputDecoration(
                  labelText: 'Worksheet Description / Label',
                  hintText: 'Plot (10\' - 5" × 70\' - 0")',
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
                onTap: () => _handleFieldTap(_plotLabelCtrl, 'Plot (10\' - 5" × 70\' - 0")'),
                onChanged: (val) {
                  _userEditedPlotLabel = val.trim().isNotEmpty;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Result Card
        _buildResultCard(
          result: result,
          onAdd: () => _addToWorksheet(isDimensionsMode: true),
          onExport: () => _openExportDialog(isDimensionsMode: true),
          formulaText:
              '(${_widthFeetCtrl.text.isEmpty ? '0' : _widthFeetCtrl.text}\' - ${_widthInchesCtrl.text.isEmpty ? '0' : _widthInchesCtrl.text}" = ${result.widthInches.toStringAsFixed(1)}") × '
              '(${_lengthFeetCtrl.text.isEmpty ? '0' : _lengthFeetCtrl.text}\' - ${_lengthInchesCtrl.text.isEmpty ? '0' : _lengthInchesCtrl.text}" = ${result.lengthInches.toStringAsFixed(1)}") = '
              '${result.totalSquareInches.toStringAsFixed(0)} sq in ÷ 144 = ${result.squareFeetFormatted} sq ft',
          isDimensionsMode: true,
        ),
      ],
    );
  }

  /// Mode 1: Direct Sq Ft to Land Units
  Widget _buildDirectSqFtMode() {
    final result = _directSqFtResult;

    final presets = [
      (label: '1 Sarsai', sqFt: 30.25),
      (label: '1 Marla', sqFt: 272.25),
      (label: '3 Marla', sqFt: 816.75),
      (label: '5 Marla', sqFt: 1361.25),
      (label: '10 Marla', sqFt: 2722.50),
      (label: '1 Kanal', sqFt: 5445.00),
      (label: '1 Acre', sqFt: 43560.00),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Input Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate_outlined, color: AppTheme.primaryNavy, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Direct Square Feet Input (اسکوائر فٹ)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _resetToNew,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('New / Clear', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentTeal,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter total square feet to instantly convert into Kanal, Marla, and Sarsai.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _directSqFtCtrl,
                focusNode: _directSqFtFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Square Feet (sq ft)',
                  hintText: '0.0',
                  suffixText: 'sq ft',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _directSqFtCtrl.clear();
                      setState(() {});
                    },
                  ),
                ),
                onTap: () => _handleFieldTap(_directSqFtCtrl, '729.17'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              const Text(
                'Quick Presets:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presets.map((p) {
                  return ActionChip(
                    label: Text('${p.label} (${p.sqFt})'),
                    labelStyle: const TextStyle(fontSize: 11),
                    onPressed: () {
                      setState(() {
                        _directSqFtCtrl.text = p.sqFt.toString();
                        _directLabelCtrl.text = p.label;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _directLabelCtrl,
                focusNode: _directLabelFocus,
                decoration: const InputDecoration(
                  labelText: 'Worksheet Description / Label',
                  hintText: 'Custom Plot Area',
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
                onTap: () => _handleFieldTap(_directLabelCtrl, 'Custom Plot Area'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Result Card
        _buildResultCard(
          result: result,
          onAdd: () => _addToWorksheet(isDimensionsMode: false),
          onExport: () => _openExportDialog(isDimensionsMode: false),
          formulaText: 'Based on official 272.25 sq ft/Marla and 30.25 sq ft/Sarsai standard conversion.',
          isDimensionsMode: false,
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required DimensionCalculationResult result,
    required VoidCallback onAdd,
    required VoidCallback onExport,
    required String formulaText,
    required bool isDimensionsMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CALCULATED MEASUREMENT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.accentTeal,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: AppTheme.accentTeal),
                    tooltip: 'Copy results',
                    onPressed: () {
                      final plotDesc = _selectedMode == 0
                          ? _plotLabelCtrl.text.trim()
                          : _directLabelCtrl.text.trim();
                      final descPrefix = plotDesc.isNotEmpty ? '$plotDesc\n' : '';
                      final text = _includeSqYards
                          ? '$descPrefix${result.compositeArea.toDisplayString()} = Area: ${result.squareFeetFormatted} sq ft (${result.squareYardsFormatted} sq yards)'
                          : '$descPrefix${result.compositeArea.toDisplayString()} = Area: ${result.squareFeetFormatted} sq ft';
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Measurement copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 18, color: AppTheme.primaryNavy),
                    tooltip: 'Export & Share PDF / Word / CSV',
                    onPressed: onExport,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Land Equivalent Highlight (Dashed format)
          Text(
            result.compositeArea.toDisplayString(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 10),

          // Square Feet & Yards Row with Checkbox for Square Yards
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Square Feet (مربع فٹ)',
                  value: '${result.squareFeetFormatted} sq ft',
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _includeSqYards ? AppTheme.accentTeal.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _includeSqYards ? AppTheme.accentTeal : AppTheme.dividerColor,
                      width: _includeSqYards ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Square Yards / Gaj (گز)',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: Tooltip(
                              message: 'Include in record / worksheet entry',
                              child: Checkbox(
                                value: _includeSqYards,
                                activeColor: AppTheme.accentTeal,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  setState(() {
                                    _includeSqYards = val ?? false;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${result.squareYardsFormatted} yards',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _includeSqYards ? AppTheme.accentTeal : AppTheme.primaryNavy,
                            ),
                          ),
                          if (_includeSqYards) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.accentTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'In Record',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentTeal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Formula / explanation note
          Text(
            _includeSqYards
                ? '$formulaText\n✓ Square Yards (گز) included in worksheet and export report.'
                : '$formulaText\n• Check the box above to include Square Yards (گز) in record & report.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Add to Worksheet + Export / Print PDF
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text(
                    'Add to Land Worksheet',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text(
                    'Export / Print PDF',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryNavy,
                    side: const BorderSide(color: AppTheme.primaryNavy, width: 1.2),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPrimary ? AppTheme.accentTeal : AppTheme.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}
