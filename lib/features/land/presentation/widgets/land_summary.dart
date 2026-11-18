import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../logic/land_math.dart';

class LandSummaryWidget extends StatelessWidget {
  final LandWorksheetSummary summary;

  const LandSummaryWidget({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final isNegative = summary.isNegative;
    final deductPct = summary.deductionPercentage.toStringAsFixed(1);
    final remainPct = summary.remainingPercentage.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNegative
              ? AppTheme.dangerRed.withValues(alpha: 0.5)
              : AppTheme.dividerColor,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 18, color: AppTheme.primaryNavy),
              SizedBox(width: 8),
              Text(
                'COLONY & LAND AREA BREAKDOWN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Total Gross Area Row
          _buildRow(
            'Gross Colony Area (کل رقبہ)',
            '${summary.grossCompositeArea.toDisplayString()}  (${summary.totalAddedSqFtFormatted} sq ft)',
            color: AppTheme.primaryNavy,
            fontSize: 13,
          ),
          const SizedBox(height: 6),

          // Total Deductions Row
          _buildRow(
            'Total Deductions (کل منہائی)',
            '${summary.totalDeductedCompositeArea.toDisplayString()}  (${summary.totalDeductedSqFtFormatted} sq ft)',
            badge: summary.totalAddedUnits > 0 ? '$deductPct%' : null,
            badgeColor: AppTheme.dangerRed,
            color: AppTheme.dangerRed,
            fontSize: 13,
          ),
          const Divider(height: 18, color: AppTheme.dividerColor),

          // Net Remaining Area Highlight Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isNegative
                  ? AppTheme.dangerRed.withValues(alpha: 0.08)
                  : const Color(0xFFF0F8F6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isNegative
                    ? AppTheme.dangerRed.withValues(alpha: 0.4)
                    : AppTheme.accentTeal.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REMAINING COLONY AREA (بقایا رقبہ)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isNegative ? AppTheme.dangerRed : AppTheme.accentTeal,
                      ),
                    ),
                    if (summary.totalAddedUnits > 0 && !isNegative)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$remainPct% Remaining',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  summary.netCompositeArea.toDisplayString(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isNegative ? AppTheme.dangerRed : AppTheme.primaryNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'Square Feet Equivalent: ',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    Text(
                      '${summary.netSqFtFormatted} sq ft',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isNegative ? AppTheme.dangerRed : AppTheme.accentTeal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isNegative) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.dangerRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.dangerRed),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Warning: Total deductions exceed the gross colony area. Remaining area is negative.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.dangerRed,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
    Color? color,
    String? badge,
    Color? badgeColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? AppTheme.textMuted,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppTheme.primaryNavy).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? AppTheme.primaryNavy,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppTheme.primaryNavy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
