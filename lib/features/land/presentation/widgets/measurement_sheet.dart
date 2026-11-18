import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../logic/land_math.dart';
import '../../state/land_row_model.dart';
import 'measurement_row.dart';

class MeasurementSheetWidget extends StatelessWidget {
  final List<LandRowModel> rows;
  final List<String> purposeSuggestions;
  final void Function(int index) onToggleSign;
  final void Function(int index, String purpose) onPurposeChanged;
  final void Function(int index) onValuesChanged;
  final void Function(int index) onDeleteRow;
  final VoidCallback onAddRow;
  final VoidCallback onDeductRow;
  final bool isNarrow;
  final List<int>? runningBalances;
  final int grossCenti;

  const MeasurementSheetWidget({
    super.key,
    required this.rows,
    required this.purposeSuggestions,
    required this.onToggleSign,
    required this.onPurposeChanged,
    required this.onValuesChanged,
    required this.onDeleteRow,
    required this.onAddRow,
    required this.onDeductRow,
    required this.isNarrow,
    this.runningBalances,
    this.grossCenti = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Row(
            children: [
              const Text(
                'MEASUREMENTS & DEDUCTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Divider(color: AppTheme.dividerColor, thickness: 1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Column Headers (Visible when wide)
          if (!isNarrow) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  SizedBox(width: 40), // sign width + gap
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Purpose / Amenity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      'Kanal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Marla',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  SizedBox(
                    width: 68,
                    child: Text(
                      'Sarsai',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Sq Ft & Balance',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(width: 34), // delete button + gap
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.dividerColor),
          ],
          // Continuous Sheet Entries with Thin Dividers
          ...List.generate(rows.length, (index) {
            final row = rows[index];

            String? runningRemaining;
            if (runningBalances != null && index < runningBalances!.length) {
              final balComposite = LandMath.centiSarsaiToComposite(runningBalances![index]);
              runningRemaining = balComposite.toDisplayString();
            }

            double? pct;
            if (grossCenti > 0 && row.centiSarsai > 0) {
              pct = (row.centiSarsai / grossCenti) * 100.0;
            }

            return Column(
              key: ValueKey(row.keyId),
              children: [
                if (index > 0)
                  const Divider(height: 1, color: Color(0xFFEAEFF4)),
                MeasurementRowWidget(
                  index: index,
                  row: row,
                  purposeSuggestions: purposeSuggestions,
                  onToggleSign: () => onToggleSign(index),
                  onPurposeChanged: (p) => onPurposeChanged(index, p),
                  onValuesChanged: () => onValuesChanged(index),
                  onDelete: () => onDeleteRow(index),
                  isNarrow: isNarrow,
                  percentageOfGross: pct,
                  runningRemaining: runningRemaining,
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.dividerColor),
          const SizedBox(height: 10),
          // Single-tap Append Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddRow,
                  icon: const Icon(Icons.add, size: 18, color: AppTheme.accentTeal),
                  label: const Text(
                    '+ Add',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentTeal,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accentTeal),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDeductRow,
                  icon: const Icon(Icons.remove, size: 18, color: AppTheme.dangerRed),
                  label: const Text(
                    '− Deduct',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dangerRed,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.dangerRed),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
