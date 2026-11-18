import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../land/state/land_controller.dart';
import '../logic/dimension_math.dart';

class DimensionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToLand;

  const DimensionScreen({super.key, this.onNavigateToLand});

  @override
  ConsumerState<DimensionScreen> createState() => _DimensionScreenState();
}

class _DimensionScreenState extends ConsumerState<DimensionScreen> {
  int _selectedMode = 0; // 0: Dimensions (Length x Width), 1: Direct Sq Ft

  // Mode 0 Controllers (Feet & Inches)
  final TextEditingController _widthFeetCtrl = TextEditingController(text: '10');
  final TextEditingController _widthInchesCtrl = TextEditingController(text: '5');
  final TextEditingController _lengthFeetCtrl = TextEditingController(text: '70');
  final TextEditingController _lengthInchesCtrl = TextEditingController(text: '0');
  final TextEditingController _plotLabelCtrl = TextEditingController(text: 'Plot (10\'5" × 70\')');

  // Mode 1 Controller (Direct Sq Ft)
  final TextEditingController _directSqFtCtrl = TextEditingController(text: '729.17');
  final TextEditingController _directLabelCtrl = TextEditingController(text: 'Custom Plot Area');

  @override
  void dispose() {
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
    setState(() {
      _plotLabelCtrl.text =
          'Plot (${_widthFeetCtrl.text}\'${_widthInchesCtrl.text}" × ${_lengthFeetCtrl.text}\'${_lengthInchesCtrl.text}")';
    });
  }

  void _addToWorksheet({required bool isDimensionsMode}) {
    final result = isDimensionsMode ? _dimensionResult : _directSqFtResult;
    final label = isDimensionsMode
        ? (_plotLabelCtrl.text.trim().isEmpty ? 'Plot Dimension' : _plotLabelCtrl.text.trim())
        : (_directLabelCtrl.text.trim().isEmpty ? 'Square Feet Entry' : _directLabelCtrl.text.trim());

    final landCtrl = ref.read(landControllerProvider);
    landCtrl.appendCalculatedPlot(
      purpose: label,
      kanal: result.compositeArea.kanal,
      marla: result.compositeArea.marla,
      sarsaiCenti: result.compositeArea.sarsaiCenti,
      isSubtract: false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$label" (${result.compositeArea.toDisplayString()}) to Land Worksheet!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plot Dimensions & Converter'),
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
              const Row(
                children: [
                  Icon(Icons.straighten, color: AppTheme.primaryNavy, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Building Drawing / Site Plan Inputs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Feet (فٹ)',
                        suffixText: 'ft',
                      ),
                      onChanged: (_) => _onDimensionsChanged(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _widthInchesCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Inches (انچ)',
                        suffixText: 'in',
                      ),
                      onChanged: (_) => _onDimensionsChanged(),
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
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Feet (فٹ)',
                        suffixText: 'ft',
                      ),
                      onChanged: (_) => _onDimensionsChanged(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _lengthInchesCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Inches (انچ)',
                        suffixText: 'in',
                      ),
                      onChanged: (_) => _onDimensionsChanged(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Plot Label Field
              TextFormField(
                controller: _plotLabelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Worksheet Description / Label',
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Result Card
        _buildResultCard(
          result: result,
          onAdd: () => _addToWorksheet(isDimensionsMode: true),
          formulaText:
              '(${_widthFeetCtrl.text}\' ${_widthInchesCtrl.text}" = ${result.widthInches.toStringAsFixed(1)}") × '
              '(${_lengthFeetCtrl.text}\' ${_lengthInchesCtrl.text}" = ${result.lengthInches.toStringAsFixed(1)}") = '
              '${result.totalSquareInches.toStringAsFixed(0)} sq in ÷ 144 = ${result.squareFeetFormatted} sq ft',
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
              const Row(
                children: [
                  Icon(Icons.calculate_outlined, color: AppTheme.primaryNavy, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Direct Square Feet Input (اسکوائر فٹ)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter total square feet to instantly convert into Kanal, Marla, and Sarsai.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _directSqFtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Square Feet (sq ft)',
                  suffixText: 'sq ft',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _directSqFtCtrl.clear();
                      setState(() {});
                    },
                  ),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Worksheet Description / Label',
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Result Card
        _buildResultCard(
          result: result,
          onAdd: () => _addToWorksheet(isDimensionsMode: false),
          formulaText: 'Based on official 272.25 sq ft/Marla and 30.25 sq ft/Sarsai standard conversion.',
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required DimensionCalculationResult result,
    required VoidCallback onAdd,
    required String formulaText,
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
              IconButton(
                icon: const Icon(Icons.copy, size: 18, color: AppTheme.accentTeal),
                tooltip: 'Copy results',
                onPressed: () {
                  final text =
                      'Area: ${result.squareFeetFormatted} sq ft (${result.squareYardsFormatted} sq yards) = ${result.compositeArea.toDisplayString()}';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Measurement copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Land Equivalent Highlight
          Text(
            result.compositeArea.toDisplayString(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),

          // Square Feet & Yards Row
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
                child: _buildMetricTile(
                  label: 'Square Yards / Gaj (گز)',
                  value: '${result.squareYardsFormatted} yards',
                  isPrimary: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Formula / explanation note
          Text(
            formulaText,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),

          // Add to Worksheet Button
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.playlist_add, size: 20),
            label: const Text(
              'Add to Land Worksheet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
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
