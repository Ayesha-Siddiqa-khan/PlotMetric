import 'package:flutter/material.dart';
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
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: row.purpose),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return purposeSuggestions;
        }
        return purposeSuggestions.where((p) => p.toLowerCase().contains(query));
      },
      onSelected: (String selection) {
        onPurposeChanged(selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (controller.text != row.purpose) {
          controller.text = row.purpose;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: 'Purpose (e.g. Roads)',
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
            onPurposeChanged(val);
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

  Widget _buildKanalField(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TextFormField(
        controller: row.kanalController,
        focusNode: row.kanalFocus,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: '0',
          errorText: row.kanalError,
          errorStyle: const TextStyle(fontSize: 9, height: 1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        onChanged: (_) => onValuesChanged(),
        onFieldSubmitted: (_) => row.marlaFocus.requestFocus(),
      ),
    );
  }

  Widget _buildMarlaField(BuildContext context) {
    return SizedBox(
      width: 60,
      child: TextFormField(
        controller: row.marlaController,
        focusNode: row.marlaFocus,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: '0',
          errorText: row.marlaError,
          errorStyle: const TextStyle(fontSize: 9, height: 1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        onChanged: (_) => onValuesChanged(),
        onFieldSubmitted: (_) => row.sarsaiFocus.requestFocus(),
      ),
    );
  }

  Widget _buildSarsaiField(BuildContext context) {
    return SizedBox(
      width: 68,
      child: TextFormField(
        controller: row.sarsaiController,
        focusNode: row.sarsaiFocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: '0',
          errorText: row.sarsaiError,
          errorStyle: const TextStyle(fontSize: 9, height: 1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
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
          // Line 1: Sign + Purpose + Delete
          Row(
            children: [
              _buildSignButton(),
              const SizedBox(width: 8),
              Expanded(child: _buildPurposeField(context)),
              if (index > 0) ...[
                const SizedBox(width: 4),
                _buildDeleteButton(),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Line 2: Kanal + Marla + Sarsai + Sq Ft
          Row(
            children: [
              _buildKanalField(context),
              const SizedBox(width: 4),
              _buildMarlaField(context),
              const SizedBox(width: 4),
              _buildSarsaiField(context),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSqFtDisplay(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
