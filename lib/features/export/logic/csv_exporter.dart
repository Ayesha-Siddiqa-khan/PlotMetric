import '../../../data/models/calculation.dart';
import '../../land/logic/land_math.dart';
import '../../../core/utils/date_time_formatters.dart';

/// Generates RFC-4180 compliant CSV exports for PlotMetric
class CsvExporter {
  /// Exports a single calculation to CSV string
  static String exportCalculation(Calculation calculation) {
    return exportCalculations([calculation]);
  }

  /// Exports multiple calculations to a single consolidated CSV string
  static String exportCalculations(List<Calculation> calculations) {
    final buffer = StringBuffer();

    // CSV Header row
    buffer.writeln([
      'Record ID',
      'Title',
      'Date',
      'Time',
      'Item No',
      'Purpose / Deduction',
      'Operation',
      'Kanal',
      'Marla',
      'Sarsai',
      'Square Feet',
      'Running Balance (K-M-S)',
      'Running Balance (Sq Ft)',
    ].map(_escapeField).join(','));

    for (final calc in calculations) {
      int runningCenti = 0;
      final displayDate = DateTimeFormatters.storageToDisplayDate(calc.calculationDate);
      final displayTime = DateTimeFormatters.storageToDisplayTime(calc.calculationTime);

      for (int i = 0; i < calc.entries.length; i++) {
        final entry = calc.entries[i];
        final rowCenti = LandMath.rowToCentiSarsai(
          kanal: entry.kanal,
          marla: entry.marla,
          sarsaiCenti: entry.sarsaiCenti,
        );

        if (entry.isSubtract) {
          runningCenti -= rowCenti;
        } else {
          runningCenti += rowCenti;
        }

        final area = LandMath.centiSarsaiToCompositeArea(rowCenti);
        final sqFt = LandMath.centiSarsaiToSquareFeet(rowCenti).toStringAsFixed(2);

        final balArea = LandMath.centiSarsaiToCompositeArea(runningCenti.abs());
        final balSign = runningCenti < 0 ? '-' : '';
        final balStr = '$balSign${balArea.kanal}K - ${balArea.marla}M - ${balArea.sarsaiFormatted}S';
        final balSqFt = (runningCenti < 0 ? '-' : '') +
            LandMath.centiSarsaiToSquareFeet(runningCenti.abs()).toStringAsFixed(2);

        buffer.writeln([
          calc.id?.toString() ?? '',
          calc.title,
          displayDate,
          displayTime,
          '${i + 1}',
          entry.purpose,
          entry.isSubtract ? 'SUBTRACT' : 'ADD',
          '${area.kanal}',
          '${area.marla}',
          area.sarsaiFormatted,
          sqFt,
          balStr,
          balSqFt,
        ].map(_escapeField).join(','));
      }
    }

    return buffer.toString();
  }

  static String _escapeField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }
}
