import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../state/land_row_model.dart';

class MeasurementRowWidget extends StatelessWidget {
  final int index;
  final LandRowModel row;
  final List<String> purposeSuggestions;
  final VoidCallback onToggleSign;
  final ValueChanged<String> onPurposeChanged;
  final VoidCallback onValuesChanged;
  final VoidCallback onDelete;
  final bool isNarrow;
  final double? percentageOfGross;
  final String? runningRemaining;

  const MeasurementRowWidget({
    super.key,
    required this.index,
    required this.row,
    required this.purposeSuggestions,
    required this.onToggleSign,
    required this.onPurposeChanged,
    required this.onValuesChanged,
    required this.onDelete,
    required this.isNarrow,
    this.percentageOfGross,
    this.runningRemaining,
  });

  @override
  Widget build(BuildContext context) {
    if (isNarrow) {
      return _buildNarrowLayout(context);
    } else {
      return _buildWideLayout(context);
    }
  }

  Widget _buildSignButton() {
    final isSubtract = row.isSubtract;
    return InkWell(
      onTap: index == 0 ? null : onToggleSign,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSubtract
              ? AppTheme.dangerRed.withValues(alpha: 0.12)
              : AppTheme.accentTeal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSubtract ? AppTheme.dangerRed : AppTheme.accentTeal,
            width: 1,
          ),
        ),
        child: Text(
          isSubtract ? '−' : '+',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isSubtract ? AppTheme.dangerRed : AppTheme.accentTeal,
          ),
        ),
      ),
    );
  }

  Widget _buildPurposeField(BuildContext context) {
    return RawAutocomplete<String>(
      focusNode: row.purposeFocus,
      textEditingController: row.purposeController,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query == 'nil') return const <String>[];
        if (query.isEmpty) {
          return purposeSuggestions;
        }
        return purposeSuggestions.where((p) => p.toLowerCase().contains(query));
      },
      onSelected: (String selection) {
        row.purposeController.text = selection;
        onPurposeChanged(selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          maxLength: 60,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => row.kanalFocus.requestFocus(),
          onTap: () {
            if (controller.text == 'Nil' || controller.text == '') {
              controller.clear();
            } else {
              controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
            }
          },
          decoration: InputDecoration(
            hintText: 'Nil',
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            suffixIcon: percentageOfGross != null && percentageOfGross! > 0 && row.isSubtract
                ? Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${percentageOfGross!.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.dangerRed,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 14),
          onChanged: (val) {
            final effective = val.trim().isEmpty ? 'Nil' : val;
            onPurposeChanged(effective);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(option, style: const TextStyle(fontSize: 13)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKanalField(BuildContext context, {double width = 72}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: row.kanalController,
        focusNode: row.kanalFocus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: width < 60 ? 13 : 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: '0',
          errorText: row.kanalError,
          errorStyle: const TextStyle(fontSize: 9, height: 1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        ),
        onTap: () {
          if (row.kanalController.text == '0' || row.kanalController.text.isEmpty) {
            row.kanalController.clear();
          } else {
            row.kanalController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: row.kanalController.text.length,
            );
          }
        },
        onChanged: (_) => onValuesChanged(),
        onFieldSubmitted: (_) => row.marlaFocus.requestFocus(),
      ),
    );
  }

  Widget _buildMarlaField(BuildContext context, {double width = 60}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: row.marlaController,
        focusNode: row.marlaFocus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: width < 50 ? 13 : 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: '0',
          errorText: row.marlaError,
          errorStyle: const TextStyle(fontSize: 9, height: 1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        ),
        onTap: () {
          if (row.marlaController.text == '0' || row.marlaController.text.isEmpty) {
            row.marlaController.clear();
          } else {
            row.marlaController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: row.marlaController.text.length,
            );
          }
        },
        onChanged: (_) => onValuesChanged(),
        onFieldSubmitted: (_) => row.sarsaiFocus.requestFocus(),
      ),
    );
  }

  Widget _buildSarsaiField(BuildContext context, {double width = 68}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: row.sarsaiController,
        focusNode: row.sarsaiFocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: width < 55 ? 13 : 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: '0',
          errorText: row.sarsaiError,
          errorStyle: const TextStyle(fontSize: 9, height: 1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        ),
        onTap: () {
          if (row.sarsaiController.text == '0' || row.sarsaiController.text.isEmpty) {
            row.sarsaiController.clear();
          } else {
            row.sarsaiController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: row.sarsaiController.text.length,
            );
          }
        },
        onChanged: (_) => onValuesChanged(),
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _buildSqFtDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${row.sqFtFormatted} sq ft',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: row.isSubtract ? AppTheme.dangerRed : AppTheme.accentTeal,
          ),
        ),
        if (runningRemaining != null)
          Text(
            'Bal: $runningRemaining',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    if (index == 0) {
      return const SizedBox(width: 28);
    }
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: const Icon(Icons.close, color: AppTheme.dangerRed),
        tooltip: 'Delete row',
        onPressed: onDelete,
      ),
    );
  }

  /// Wide layout (Desktop / Tablet / Landscape)
  Widget _buildWideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (index == 0)
            const SizedBox(width: 32)
          else
            _buildSignButton(),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _buildPurposeField(context),
          ),
          const SizedBox(width: 8),
          _buildKanalField(context),
          const SizedBox(width: 6),
          _buildMarlaField(context),
          const SizedBox(width: 6),
          _buildSarsaiField(context),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _buildSqFtDisplay(),
          ),
          const SizedBox(width: 6),
          _buildDeleteButton(),
        ],
      ),
    );
  }

  /// Narrow layout (Phone portrait)
  Widget _buildNarrowLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Line 1: Purpose (Total Area) + Kanal + Marla + Sarsai + Delete Button
          Row(
            children: [
              Expanded(
                child: _buildPurposeField(context),
              ),
              const SizedBox(width: 6),
              _buildKanalField(context, width: 52),
              const SizedBox(width: 4),
              _buildMarlaField(context, width: 44),
              const SizedBox(width: 4),
              _buildSarsaiField(context, width: 48),
              const SizedBox(width: 4),
              _buildDeleteButton(),
            ],
          ),
          const SizedBox(height: 4),
          // Line 2: Sign / Type Toggle (for row > 0) + Total Square Feet & Balance
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (index > 0)
                  InkWell(
                    onTap: onToggleSign,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: row.isSubtract
                            ? AppTheme.dangerRed.withValues(alpha: 0.1)
                            : AppTheme.accentTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: row.isSubtract ? AppTheme.dangerRed : AppTheme.accentTeal,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            row.isSubtract ? Icons.remove : Icons.add,
                            size: 11,
                            color: row.isSubtract ? AppTheme.dangerRed : AppTheme.accentTeal,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            row.isSubtract ? 'Deduct' : 'Add',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: row.isSubtract ? AppTheme.dangerRed : AppTheme.accentTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${row.sqFtFormatted} sq ft',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: row.isSubtract ? AppTheme.dangerRed : AppTheme.accentTeal,
                      ),
                    ),
                    if (runningRemaining != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '•  Bal: $runningRemaining',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
