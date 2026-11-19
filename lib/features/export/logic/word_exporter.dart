import '../../../core/utils/date_time_formatters.dart';
import '../../../data/models/calculation.dart';
import '../../land/logic/land_math.dart';

/// Exports PlotMetric calculation reports as styled Microsoft Word documents (.doc)
/// Compatible with Microsoft Word, LibreOffice, Google Docs, and WPS Office.
class WordExporter {
  /// Exports a single calculation to a formatted Word HTML document
  static String exportCalculation(
    Calculation calculation, {
    String? subtitle,
    String? metadataLine,
    String? summaryTitle,
    String? totalAreaLabel,
    String? totalDeductionsLabel,
    String? netBalanceLabel,
  }) {
    return exportCalculations(
      [calculation],
      title: calculation.title.isEmpty
          ? 'Colony Land Measurement Report'
          : calculation.title,
      subtitle: subtitle,
      metadataLine: metadataLine,
      summaryTitle: summaryTitle,
      totalAreaLabel: totalAreaLabel,
      totalDeductionsLabel: totalDeductionsLabel,
      netBalanceLabel: netBalanceLabel,
    );
  }

  /// Exports multiple calculations to a formatted Word HTML document
  static String exportCalculations(
    List<Calculation> calculations, {
    String title = 'PlotMetric Complete Records Report',
    String? subtitle,
    String? metadataLine,
    String? summaryTitle,
    String? totalAreaLabel,
    String? totalDeductionsLabel,
    String? netBalanceLabel,
  }) {
    final buffer = StringBuffer();
    final effectiveSubtitle =
        (subtitle ?? 'LAND MEASUREMENT & COLONY DEDUCTION REPORT').trim();
    final defaultGeneratedOn =
        'Generated: ${DateTime.now().toLocal().toString().split('.').first} | 1 Kanal = 20 Marlas | 1 Marla = 9 Sarsais (272.25 sq ft) | 1 Sarsai = 30.25 sq ft';
    final effectiveMetadata = (metadataLine ?? defaultGeneratedOn).trim();

    buffer.writeln('''
<html xmlns:o='urn:schemas-microsoft-com:office:office'
      xmlns:w='urn:schemas-microsoft-com:office:word'
      xmlns='http://www.w3.org/TR/REC-html40'>
<head>
<meta charset='utf-8'>
<title>${_escapeHtml(title)}</title>
<!--[if gte mso 9]>
<xml>
<w:WordDocument>
<w:View>Print</w:View>
<w:Zoom>100</w:Zoom>
<w:DoNotOptimizeForBrowser/>
</w:WordDocument>
</xml>
<![endif]-->
<style>
body {
  font-family: 'Calibri', 'Arial', sans-serif;
  color: #000000;
  margin: 20mm;
}
.doc-title {
  text-align: center;
  font-size: 18pt;
  font-weight: bold;
  margin-bottom: 4pt;
}
.doc-sub {
  text-align: center;
  font-size: 12pt;
  font-weight: bold;
  color: #222222;
  margin-bottom: 4pt;
}
.meta-info {
  text-align: center;
  font-size: 10pt;
  color: #555555;
  margin-bottom: 16pt;
}
hr.divider {
  border: 0;
  border-top: 1.5pt solid #000000;
  margin-bottom: 16pt;
}
.scheme-card {
  margin-bottom: 24pt;
  page-break-inside: avoid;
}
.scheme-header {
  text-align: center;
  font-size: 13pt;
  font-weight: bold;
  margin-bottom: 3pt;
}
.scheme-meta {
  text-align: center;
  font-size: 10pt;
  color: #666666;
  margin-bottom: 8pt;
}
table.data-table {
  width: 100%;
  border-collapse: collapse;
  margin-bottom: 10pt;
}
table.data-table th {
  border: 1pt solid #000000;
  background-color: #f0f0f0;
  font-size: 10pt;
  font-weight: bold;
  text-align: center;
  padding: 6pt 4pt;
}
table.data-table td {
  border: 1pt solid #000000;
  font-size: 10pt;
  text-align: center;
  padding: 5pt 4pt;
}
.summary-box {
  border: 1.5pt solid #000000;
  background-color: #fafafa;
  padding: 10pt;
  margin-top: 8pt;
}
.summary-title {
  text-align: center;
  font-size: 11pt;
  font-weight: bold;
  border-bottom: 1pt solid #999999;
  padding-bottom: 4pt;
  margin-bottom: 6pt;
}
.summary-row {
  text-align: center;
  font-size: 10pt;
  margin-bottom: 4pt;
}
.summary-net {
  text-align: center;
  font-size: 11pt;
  font-weight: bold;
  margin-top: 6pt;
  color: #000000;
}
</style>
</head>
<body>
  <div class="doc-title">${_escapeHtml(title)}</div>
  ${effectiveSubtitle.isNotEmpty ? '<div class="doc-sub">${_escapeHtml(effectiveSubtitle)}</div>' : ''}
  ${effectiveMetadata.isNotEmpty ? '<div class="meta-info">${_escapeHtml(effectiveMetadata)}</div>' : ''}
  <hr class="divider"/>
''');

    for (int calcIdx = 0; calcIdx < calculations.length; calcIdx++) {
      final calc = calculations[calcIdx];
      final displayDate = DateTimeFormatters.storageToDisplayDate(
        calc.calculationDate,
      );
      final displayTime = DateTimeFormatters.storageToDisplayTime(
        calc.calculationTime,
      );

      buffer.writeln('<div class="scheme-card">');
      if (calculations.length > 1) {
        buffer.writeln(
          '<div class="scheme-header">Scheme #${calcIdx + 1}: ${_escapeHtml(calc.title.isEmpty ? "(Untitled)" : calc.title)}</div>',
        );
        buffer.writeln(
          '<div class="scheme-meta">Date: $displayDate &nbsp;|&nbsp; Time: $displayTime</div>',
        );
      }

      buffer.writeln('''
<table class="data-table">
  <thead>
    <tr>
      <th style="width: 5%;">Sr.</th>
      <th style="width: 25%;">Purpose / Deduction</th>
      <th style="width: 10%;">Type</th>
      <th style="width: 10%;">Kanal</th>
      <th style="width: 10%;">Marla</th>
      <th style="width: 10%;">Sarsai</th>
      <th style="width: 15%;">Square Feet</th>
      <th style="width: 15%;">Running Balance</th>
    </tr>
  </thead>
  <tbody>
''');

      int runningCenti = 0;
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
        final sqFt = LandMath.centiSarsaiToSquareFeet(
          rowCenti,
        ).toStringAsFixed(2);
        final balArea = LandMath.centiSarsaiToCompositeArea(runningCenti.abs());
        final balSign = runningCenti < 0 ? '-' : '';
        final balStr =
            '$balSign${balArea.kanal}K - ${balArea.marla}M - ${balArea.sarsaiFormatted}S';

        buffer.writeln('''
    <tr>
      <td>${i + 1}</td>
      <td><strong>${_escapeHtml(entry.purpose.isEmpty ? "Nil" : entry.purpose)}</strong></td>
      <td>${entry.isSubtract ? "(-) SUB" : "(+) ADD"}</td>
      <td>${area.kanal}</td>
      <td>${area.marla}</td>
      <td>${area.sarsaiFormatted}</td>
      <td>$sqFt</td>
      <td><strong>$balStr</strong></td>
    </tr>
''');
      }

      buffer.writeln('''
  </tbody>
</table>
''');

      final summary = calc.summary;
      final effectiveSummaryTitle = _escapeHtml(
        (summaryTitle != null && summaryTitle.trim().isNotEmpty)
            ? summaryTitle.trim()
            : 'SUMMARY & NET REMAINING BALANCE',
      );
      final effectiveAreaLabel = _escapeHtml(
        (totalAreaLabel != null && totalAreaLabel.trim().isNotEmpty)
            ? totalAreaLabel.trim()
            : 'Total Colony Area (+)',
      );
      final effectiveDeductionsLabel = _escapeHtml(
        (totalDeductionsLabel != null && totalDeductionsLabel.trim().isNotEmpty)
            ? totalDeductionsLabel.trim()
            : 'Total Deductions (Roads/Parks/Mosque) (-)',
      );
      final effectiveNetLabel = _escapeHtml(
        (netBalanceLabel != null && netBalanceLabel.trim().isNotEmpty)
            ? netBalanceLabel.trim()
            : 'NET REMAINING BALANCE',
      );

      buffer.writeln('''
<div class="summary-box">
  <div class="summary-title">$effectiveSummaryTitle</div>
  <div class="summary-row">$effectiveAreaLabel: <strong>${summary.totalAddCompositeArea.toDisplayString()}</strong> (${summary.totalAddSqFtFormatted} sq ft)</div>
  <div class="summary-row">$effectiveDeductionsLabel: <strong>${summary.totalSubtractCompositeArea.toDisplayString()}</strong> (${summary.totalSubtractSqFtFormatted} sq ft)</div>
  <div class="summary-net">$effectiveNetLabel: <strong>${summary.netCompositeArea.toDisplayString()}</strong> (${summary.netSqFtFormatted} sq ft)</div>
</div>
</div>
''');
    }

    buffer.writeln('''
</body>
</html>
''');

    return buffer.toString();
  }

  /// A landscape Word document holding one table (any headers, any rows).
  static String exportTable({
    required String title,
    String? subtitle,
    String? metadataLine,
    required List<String> headers,
    required List<List<String>> rows,
    List<bool>? centredColumns,
  }) {
    bool centred(int i) =>
        centredColumns != null &&
        i < centredColumns.length &&
        centredColumns[i];
    final buffer = StringBuffer()
      ..writeln('''
<html xmlns:o='urn:schemas-microsoft-com:office:office'
      xmlns:w='urn:schemas-microsoft-com:office:word'
      xmlns='http://www.w3.org/TR/REC-html40'>
<head>
<meta charset='utf-8'>
<title>${_escapeHtml(title)}</title>
<!--[if gte mso 9]><xml><w:WordDocument><w:View>Print</w:View><w:Zoom>100</w:Zoom></w:WordDocument></xml><![endif]-->
<style>
  @page { size: 29.7cm 21cm; mso-page-orientation: landscape; margin: 1.2cm; }
  body { font-family: Arial, sans-serif; font-size: 9pt; }
  h1 { text-align: center; font-size: 15pt; margin: 0 0 2pt 0; }
  p.sub { text-align: center; margin: 0 0 8pt 0; font-size: 9pt; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #000; padding: 3pt 4pt; vertical-align: top; }
  th { background: #e6e6e6; text-align: center; }
  td.c { text-align: center; }
</style>
</head>
<body>
<h1>${_escapeHtml(title)}</h1>''');
    if (subtitle != null && subtitle.trim().isNotEmpty) {
      buffer.writeln("<p class='sub'><b>${_escapeHtml(subtitle)}</b></p>");
    }
    if (metadataLine != null && metadataLine.trim().isNotEmpty) {
      buffer.writeln("<p class='sub'>${_escapeHtml(metadataLine)}</p>");
    }
    buffer.writeln('<table>');
    buffer.writeln(
      '<tr>${headers.map((h) => '<th>${_escapeHtml(h)}</th>').join()}</tr>',
    );
    for (final row in rows) {
      buffer.write('<tr>');
      for (var i = 0; i < headers.length; i++) {
        final value = i < row.length ? row[i] : '';
        buffer.write(
          "<td${centred(i) ? " class='c'" : ''}>${_escapeHtml(value)}</td>",
        );
      }
      buffer.writeln('</tr>');
    }
    buffer.writeln('</table>\n</body>\n</html>');
    return buffer.toString();
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
