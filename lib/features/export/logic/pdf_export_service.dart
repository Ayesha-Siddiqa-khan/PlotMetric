import 'dart:convert';
import 'dart:typed_data';
import '../../../core/utils/date_time_formatters.dart';
import '../../../data/models/calculation.dart';
import '../../land/logic/land_math.dart';
import '../../schemes/logic/scheme_report.dart';

/// Pure Dart Black & White A4 PDF Generator for PlotMetric
/// Adheres strictly to:
/// 1. Black & white styling (pure black, white, and subtle grayscale lines)
/// 2. Centralized headers, serial numbers, and centralized data values
/// 3. Minimum font size of 10pt across all elements
/// 4. Standard A4 dimensions (595.28 x 841.89 pt) with automatic multi-page pagination
/// 5. Zero third-party packages required (Standard PDF 1.4 specification)
class PdfExportService {
  static const double a4Width = 595.28;
  static const double a4Height = 841.89;
  static const double marginHorizontal = 36.0;
  static const double marginTop = 40.0;
  static const double marginBottom = 40.0;
  static const double contentWidth = a4Width - (marginHorizontal * 2); // 523.28 pt

  static Uint8List generateSchemePdf(SchemeReport report) {
    final pages = <_PdfPageContent>[];
    late _PdfPageContent page;
    var y = 0.0;
    void newPage() {
      page = _PdfPageContent();
      pages.add(page);
      y = a4Height - marginTop;
      page.drawText(report.draft ? 'HOUSING SCHEME REPORT - DRAFT' : 'HOUSING SCHEME REPORT',
        x: marginHorizontal, y: y, fontSize: 15, isBold: true);
      y -= 28;
    }
    String display(Object? value) => value is double ? value.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '')
        : value?.toString() ?? '';
    List<String> wrap(String text, int width) {
      if (text.isEmpty) return [''];
      final lines = <String>[];
      var rest = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      while (rest.length > width) {
        final lastSpace = rest.lastIndexOf(' ', width);
        final end = lastSpace > 0 ? lastSpace : width;
        lines.add(rest.substring(0, end));
        rest = rest.substring(end).trimLeft();
      }
      return [...lines, rest];
    }
    void row(List<Object?> cells, List<double> widths, {bool heading = false}) {
      final columns = [for (final (index, cell) in cells.indexed)
        wrap(display(cell), ((widths[index] - 8) / 4.8).floor().clamp(3, 180))];
      final lineCount = columns.fold<int>(1, (max, lines) => lines.length > max ? lines.length : max);
      var position = 0;
      while (position < lineCount) {
        if (y < marginBottom + 24) newPage();
        final capacity = ((y - marginBottom - 8) / 11).floor();
        final count = (lineCount - position).clamp(1, capacity);
        final height = count * 11 + 8.0;
        var x = marginHorizontal;
        for (var i = 0; i < widths.length; i++) {
          page.drawRect(x, y - height, widths[i], height, stroke: true, fillGray: heading ? 0.9 : null);
          for (var line = 0; line < count && line + position < columns[i].length; line++) {
            page.drawText(columns[i][line + position], x: x + 4, y: y - 12 - line * 11,
              fontSize: 8, isBold: heading);
          }
          x += widths[i];
        }
        y -= height;
        position += count;
      }
    }
    void table(ReportTable table) {
      if (y < marginBottom + 70) newPage();
      y -= 20;
      page.drawText(table.title, x: marginHorizontal, y: y, fontSize: 11, isBold: true);
      y -= 9;
      final widths = List.filled(table.headers.length, contentWidth / table.headers.length);
      row(table.headers, widths, heading: true);
      for (final cells in table.rows) {
        if (y < marginBottom + 44) {
          newPage();
          row(table.headers, widths, heading: true);
        }
        row(cells, widths);
      }
    }
    newPage();
    for (final detail in report.summary) {
      row([detail.first, detail.skip(1).whereType<Object>().map(display).join('   ')],
        [175, contentWidth - 175]);
    }
    table(report.schedule);
    table(report.balances);
    table(report.documents);
    if (report.totals.issues.isNotEmpty) {
      table((title: 'Review Items', headers: ['Item'],
        rows: [for (final issue in report.totals.issues) [issue]]));
    }
    final builder = _PdfLowLevelBuilder();
    for (final (index, item) in pages.indexed) {
      item.drawText('Page ${index + 1} of ${pages.length}', x: marginHorizontal, y: 24, fontSize: 8);
      builder.addPage(item.generateStream());
    }
    return builder.build();
  }

  /// Generates a print-ready black & white A4 PDF document for a single Calculation
  static Uint8List generateCalculationPdf(
    Calculation calculation, {
    String? subtitle,
    String? metadataLine,
    String? summaryTitle,
    String? totalAreaLabel,
    String? totalDeductionsLabel,
    String? netBalanceLabel,
  }) {
    return _buildPdf(
      title: calculation.title.trim().isEmpty ? 'Colony Land Measurement Report' : calculation.title.trim(),
      subtitle: subtitle,
      metadataLine: metadataLine,
      summaryTitle: summaryTitle,
      totalAreaLabel: totalAreaLabel,
      totalDeductionsLabel: totalDeductionsLabel,
      netBalanceLabel: netBalanceLabel,
      calculations: [calculation],
    );
  }

  /// Generates a comprehensive print-ready black & white A4 PDF for all saved Calculations
  static Uint8List generateAllCalculationsPdf(
    List<Calculation> calculations, {
    String title = 'PlotMetric Complete Records Report',
    String? subtitle,
    String? metadataLine,
    String? summaryTitle,
    String? totalAreaLabel,
    String? totalDeductionsLabel,
    String? netBalanceLabel,
    bool includeSummaryBox = false,
    bool includeSchemeDateTime = false,
  }) {
    return _buildPdf(
      title: title,
      subtitle: subtitle,
      metadataLine: metadataLine,
      summaryTitle: summaryTitle,
      totalAreaLabel: totalAreaLabel,
      totalDeductionsLabel: totalDeductionsLabel,
      netBalanceLabel: netBalanceLabel,
      includeSummaryBox: includeSummaryBox,
      includeSchemeDateTime: includeSchemeDateTime,
      calculations: calculations,
    );
  }

  static Uint8List _buildPdf({
    required String title,
    String? subtitle,
    String? metadataLine,
    String? summaryTitle,
    String? totalAreaLabel,
    String? totalDeductionsLabel,
    String? netBalanceLabel,
    bool includeSummaryBox = true,
    bool includeSchemeDateTime = true,
    required List<Calculation> calculations,
  }) {
    final builder = _PdfLowLevelBuilder();

    // Map all calculations into drawable pages
    final pagesContent = <_PdfPageContent>[];
    _PdfPageContent currentPage = _PdfPageContent();
    pagesContent.add(currentPage);

    double currentY = a4Height - marginTop;

    // Document Main Header (Centered, >= 10pt)
    currentPage.drawText(
      _sanitizeText(title),
      x: a4Width / 2,
      y: currentY - 18,
      fontSize: 16,
      isBold: true,
      align: _PdfTextAlign.center,
    );
    currentY -= 26;

    // Subtitle (Optional, editable)
    final effectiveSubtitle = (subtitle ?? 'LAND MEASUREMENT & COLONY DEDUCTION REPORT').trim();
    if (effectiveSubtitle.isNotEmpty) {
      currentPage.drawText(
        _sanitizeText(effectiveSubtitle),
        x: a4Width / 2,
        y: currentY - 12,
        fontSize: 10,
        isBold: true,
        align: _PdfTextAlign.center,
      );
      currentY -= 16;
    }

    // Metadata line (Optional, editable)
    final defaultGeneratedOn = 'Generated on: ${DateTime.now().toLocal().toString().split('.').first} | 1 Kanal = 20 Marlas, 1 Marla = 9 Sarsais (272.25 sq ft)';
    final effectiveMetadata = (metadataLine ?? defaultGeneratedOn).trim();
    if (effectiveMetadata.isNotEmpty) {
      currentPage.drawText(
        _sanitizeText(effectiveMetadata),
        x: a4Width / 2,
        y: currentY - 10,
        fontSize: 10,
        isBold: false,
        align: _PdfTextAlign.center,
      );
      currentY -= 14;
    }

    // Solid horizontal divider
    currentPage.drawLine(marginHorizontal, currentY, a4Width - marginHorizontal, currentY, lineWidth: 1.2);
    currentY -= 16;

    for (int calcIdx = 0; calcIdx < calculations.length; calcIdx++) {
      final calc = calculations[calcIdx];

      // Calculation Subheader
      if (calculations.length > 1) {
        if (currentY < marginBottom + 160) {
          currentPage = _PdfPageContent();
          pagesContent.add(currentPage);
          currentY = a4Height - marginTop;
        }

        final calcTitle = 'Scheme #${calcIdx + 1}: ${_sanitizeText(calc.title.isEmpty ? "(Untitled)" : calc.title)}';
        currentPage.drawText(
          calcTitle,
          x: a4Width / 2,
          y: currentY - 12,
          fontSize: 12,
          isBold: true,
          align: _PdfTextAlign.center,
        );
        currentY -= 16;

        if (includeSchemeDateTime) {
          final dateStr = 'Date: ${DateTimeFormatters.storageToDisplayDate(calc.calculationDate)}  |  Time: ${DateTimeFormatters.storageToDisplayTime(calc.calculationTime)}';
          currentPage.drawText(
            dateStr,
            x: a4Width / 2,
            y: currentY - 10,
            fontSize: 10,
            isBold: false,
            align: _PdfTextAlign.center,
          );
          currentY -= 14;
        }
      }

      // Prepare Table Data with Running Balances
      final tableRows = <_TableRowData>[];
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
        final sqFt = LandMath.centiSarsaiToSquareFeet(rowCenti).toStringAsFixed(1);
        final balArea = LandMath.centiSarsaiToCompositeArea(runningCenti.abs());
        final balSign = runningCenti < 0 ? '-' : '';
        final balStr = '$balSign${balArea.kanal}K - ${balArea.marla}M - ${balArea.sarsaiFormatted}S';

        tableRows.add(_TableRowData(
          srNo: '${i + 1}',
          purpose: _sanitizeText(entry.purpose.isEmpty ? 'Nil' : entry.purpose),
          type: entry.isSubtract ? '(-) SUB' : '(+) ADD',
          kanal: '${area.kanal}',
          marla: '${area.marla}',
          sarsai: area.sarsaiFormatted,
          sqFt: sqFt,
          balance: balStr,
        ));
      }

      // Column widths totaling exactly contentWidth (523.28 pt)
      // 1. Sr: 32
      // 2. Purpose / Deduction: 128
      // 3. Type: 44
      // 4. Kanal: 42
      // 5. Marla: 42
      // 6. Sarsai: 45
      // 7. Sq Ft: 80
      // 8. Balance: 110.28
      const colWidths = [32.0, 128.0, 44.0, 42.0, 42.0, 45.0, 80.0, 110.28];
      const colHeaders = ['Sr.', 'Purpose / Item', 'Type', 'Kanal', 'Marla', 'Sarsai', 'Square Feet', 'Running Balance'];

      // Draw Table Header
      if (currentY < marginBottom + 120) {
        currentPage = _PdfPageContent();
        pagesContent.add(currentPage);
        currentY = a4Height - marginTop;
      }

      currentY = _drawTableHeader(currentPage, currentY, colWidths, colHeaders);

      // Draw Rows
      for (final row in tableRows) {
        if (currentY < marginBottom + 60) {
          currentPage = _PdfPageContent();
          pagesContent.add(currentPage);
          currentY = a4Height - marginTop;
          currentY = _drawTableHeader(currentPage, currentY, colWidths, colHeaders);
        }

        currentY = _drawTableRow(currentPage, currentY, colWidths, row);
      }

      // Calculation Summary Box (Totals & Net Balance)
      if (includeSummaryBox) {
        final summary = calc.summary;
        if (currentY < marginBottom + 95) {
          currentPage = _PdfPageContent();
          pagesContent.add(currentPage);
          currentY = a4Height - marginTop;
        }

        currentY -= 8;
        currentY = _drawSummaryBox(
          currentPage,
          currentY,
          summary,
          summaryTitle: summaryTitle,
          totalAreaLabel: totalAreaLabel,
          totalDeductionsLabel: totalDeductionsLabel,
          netBalanceLabel: netBalanceLabel,
        );
        currentY -= 20;
      } else {
        currentY -= 16;
      }
    }

    // Add page numbers and finalize each page into builder
    for (int p = 0; p < pagesContent.length; p++) {
      final page = pagesContent[p];
      final footerText = 'Page ${p + 1} of ${pagesContent.length}  |  PlotMetric Land Measurement System';
      page.drawText(
        footerText,
        x: a4Width / 2,
        y: marginBottom - 15,
        fontSize: 10,
        isBold: false,
        align: _PdfTextAlign.center,
      );
      builder.addPage(page.generateStream());
    }

    return builder.build();
  }

  static double _drawTableHeader(
    _PdfPageContent page,
    double startY,
    List<double> widths,
    List<String> headers,
  ) {
    const rowHeight = 22.0;
    final endY = startY - rowHeight;

    // Background header fill (light gray 0.92 for crisp black & white contrast)
    page.drawRect(marginHorizontal, endY, contentWidth, rowHeight, fillGray: 0.92, stroke: true);

    double currentX = marginHorizontal;
    for (int i = 0; i < headers.length; i++) {
      final w = widths[i];
      // Vertical cell divider
      if (i > 0) {
        page.drawLine(currentX, startY, currentX, endY, lineWidth: 0.75);
      }
      // Centralized Column Header Text (>= 10pt bold)
      page.drawText(
        headers[i],
        x: currentX + (w / 2),
        y: endY + 6.5,
        fontSize: 10,
        isBold: true,
        align: _PdfTextAlign.center,
      );
      currentX += w;
    }

    return endY;
  }

  static double _drawTableRow(
    _PdfPageContent page,
    double startY,
    List<double> widths,
    _TableRowData row,
  ) {
    const rowHeight = 20.0;
    final endY = startY - rowHeight;

    // Cell outer frame
    page.drawRect(marginHorizontal, endY, contentWidth, rowHeight, stroke: true);

    final values = [
      row.srNo,
      row.purpose,
      row.type,
      row.kanal,
      row.marla,
      row.sarsai,
      row.sqFt,
      row.balance,
    ];

    double currentX = marginHorizontal;
    for (int i = 0; i < values.length; i++) {
      final w = widths[i];
      if (i > 0) {
        page.drawLine(currentX, startY, currentX, endY, lineWidth: 0.75);
      }
      // Centralized cell text (>= 10pt)
      page.drawText(
        values[i],
        x: currentX + (w / 2),
        y: endY + 5.5,
        fontSize: 10,
        isBold: (i == 0 || i == 7), // bold for Sr and Final Balance
        align: _PdfTextAlign.center,
      );
      currentX += w;
    }

    return endY;
  }

  static double _drawSummaryBox(
    _PdfPageContent page,
    double startY,
    LandWorksheetSummary summary, {
    String? summaryTitle,
    String? totalAreaLabel,
    String? totalDeductionsLabel,
    String? netBalanceLabel,
  }) {
    const boxHeight = 74.0;
    final endY = startY - boxHeight;

    // Summary Box with double-lined border feel (black and white)
    page.drawRect(marginHorizontal, endY, contentWidth, boxHeight, fillGray: 0.96, stroke: true, lineWidth: 1.0);

    final boxTitle = (summaryTitle != null && summaryTitle.trim().isNotEmpty)
        ? _sanitizeText(summaryTitle)
        : 'SUMMARY & NET REMAINING BALANCE';

    final areaLabel = (totalAreaLabel != null && totalAreaLabel.trim().isNotEmpty)
        ? _sanitizeText(totalAreaLabel)
        : 'Total Colony Area (+)';

    final deductionsLabel = (totalDeductionsLabel != null && totalDeductionsLabel.trim().isNotEmpty)
        ? _sanitizeText(totalDeductionsLabel)
        : 'Total Deductions (Roads/Parks/Mosque) (-)';

    final netLabel = (netBalanceLabel != null && netBalanceLabel.trim().isNotEmpty)
        ? _sanitizeText(netBalanceLabel)
        : 'NET REMAINING BALANCE';

    // Box Title (Centralized)
    page.drawText(
      boxTitle,
      x: a4Width / 2,
      y: startY - 14,
      fontSize: 11,
      isBold: true,
      align: _PdfTextAlign.center,
    );
    page.drawLine(marginHorizontal + 20, startY - 18, a4Width - marginHorizontal - 20, startY - 18, lineWidth: 0.5);

    final addText = '$areaLabel: ${summary.totalAddCompositeArea.toDisplayString()} (${summary.totalAddSqFtFormatted} sq ft)';
    final subText = '$deductionsLabel: ${summary.totalSubtractCompositeArea.toDisplayString()} (${summary.totalSubtractSqFtFormatted} sq ft)';
    final netText = '$netLabel: ${summary.netCompositeArea.toDisplayString()} (${summary.netSqFtFormatted} sq ft)';

    page.drawText(
      addText,
      x: a4Width / 2,
      y: startY - 32,
      fontSize: 10,
      isBold: false,
      align: _PdfTextAlign.center,
    );

    page.drawText(
      subText,
      x: a4Width / 2,
      y: startY - 48,
      fontSize: 10,
      isBold: false,
      align: _PdfTextAlign.center,
    );

    page.drawText(
      netText,
      x: a4Width / 2,
      y: startY - 65,
      fontSize: 10.5,
      isBold: true,
      align: _PdfTextAlign.center,
    );

    return endY;
  }

  /// Sanitizes text and translates common Urdu colony land terminology to English
  /// to ensure 100% standard Type-1 Helvetica compatibility without font embedding.
  static String _sanitizeText(String input) {
    String text = input.trim();
    if (text.isEmpty) return 'Nil';

    // Direct Urdu dictionary replacements
    final replacements = {
      'مسجد': 'Mosque (Masjid)',
      'جامع مسجد': 'Jamia Mosque',
      'سڑک': 'Road',
      'مین روڈ': 'Main Road',
      'قبرستان': 'Graveyard',
      'سیوریج': 'Sewerage Plant',
      'ڈسپنسری': 'Dispensary',
      'پلے گراؤنڈ': 'Playground',
      'پارک': 'Park',
      'سکول': 'School',
      'کمرشل': 'Commercial',
      'کل رقبہ': 'Total Area',
      'بقایا': 'Balance Area',
      'کنال': 'Kanal',
      'مرلہ': 'Marla',
      'سرسائی': 'Sarsai',
      'کالونی': 'Colony',
    };

    // Pre-replace common non-ASCII math and dimension punctuation with ASCII equivalents
    text = text
        .replaceAll('×', ' x ')
        .replaceAll('✕', ' x ')
        .replaceAll('✖', ' x ')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('”', '"')
        .replaceAll('“', '"')
        .replaceAll('’', "'")
        .replaceAll('‘', "'");

    for (final entry in replacements.entries) {
      if (text.contains(entry.key)) {
        text = text.replaceAll(entry.key, entry.value);
      }
    }

    // Convert any remaining non-ASCII characters to safe ASCII equivalent
    final buffer = StringBuffer();
    for (final codeUnit in text.codeUnits) {
      if (codeUnit >= 32 && codeUnit <= 126) {
        buffer.writeCharCode(codeUnit);
      } else if (codeUnit == 10 || codeUnit == 13) {
        buffer.write(' ');
      } else {
        // Safe placeholder for unsupported glyphs
        buffer.write('');
      }
    }

    final sanitized = buffer.toString().trim();
    return sanitized.isEmpty ? 'Item' : sanitized;
  }
}

class _TableRowData {
  final String srNo;
  final String purpose;
  final String type;
  final String kanal;
  final String marla;
  final String sarsai;
  final String sqFt;
  final String balance;

  const _TableRowData({
    required this.srNo,
    required this.purpose,
    required this.type,
    required this.kanal,
    required this.marla,
    required this.sarsai,
    required this.sqFt,
    required this.balance,
  });
}

enum _PdfTextAlign { left, center, right }

class _PdfPageContent {
  final StringBuffer _stream = StringBuffer();

  void drawLine(double x1, double y1, double x2, double y2, {double lineWidth = 0.75}) {
    _stream.writeln('$lineWidth w');
    _stream.writeln('0 G'); // Black stroke
    _stream.writeln('${x1.toStringAsFixed(2)} ${y1.toStringAsFixed(2)} m');
    _stream.writeln('${x2.toStringAsFixed(2)} ${y2.toStringAsFixed(2)} l S');
  }

  void drawRect(
    double x,
    double y,
    double width,
    double height, {
    double? fillGray,
    bool stroke = true,
    double lineWidth = 0.75,
  }) {
    _stream.writeln('$lineWidth w');
    if (fillGray != null) {
      _stream.writeln('$fillGray g'); // Grayscale fill
    }
    if (stroke) {
      _stream.writeln('0 G'); // Black stroke
    }
    _stream.writeln('${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${width.toStringAsFixed(2)} ${height.toStringAsFixed(2)} re');
    if (fillGray != null && stroke) {
      _stream.writeln('B'); // Fill and stroke
    } else if (fillGray != null) {
      _stream.writeln('f'); // Fill only
    } else if (stroke) {
      _stream.writeln('S'); // Stroke only
    }
  }

  void drawText(
    String text, {
    required double x,
    required double y,
    required double fontSize,
    bool isBold = false,
    _PdfTextAlign align = _PdfTextAlign.left,
  }) {
    final fontName = isBold ? '/F2' : '/F1';
    final escapedText = _escapePdfString(text);

    double posX = x;
    if (align == _PdfTextAlign.center) {
      final textWidth = _measureApproxWidth(text, fontSize, isBold: isBold);
      posX = x - (textWidth / 2);
    } else if (align == _PdfTextAlign.right) {
      final textWidth = _measureApproxWidth(text, fontSize, isBold: isBold);
      posX = x - textWidth;
    }

    _stream.writeln('BT');
    _stream.writeln('0 g'); // Pure black text
    _stream.writeln('$fontName ${fontSize.toStringAsFixed(2)} Tf');
    _stream.writeln('${posX.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Td');
    _stream.writeln('($escapedText) Tj');
    _stream.writeln('ET');
  }

  double _measureApproxWidth(String text, double fontSize, {bool isBold = false}) {
    final factor = isBold ? 0.54 : 0.50;
    return text.length * fontSize * factor;
  }

  String _escapePdfString(String str) {
    return str
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }

  String generateStream() => _stream.toString();
}

class _PdfLowLevelBuilder {

  void addPage(String pageContentStream) {
    _pageStreams.add(pageContentStream);
  }

  final List<String> _pageStreams = [];

  Uint8List build() {
    final buffer = BytesBuilder();

    void writeString(String s) {
      buffer.add(utf8.encode(s));
    }

    // PDF Header
    writeString('%PDF-1.4\n%\xe2\xe3\xcf\xd3\n');

    final offsets = <int>[];

    // Total objects calculation:
    // Obj 1: Catalog
    // Obj 2: Pages
    // Obj 3: Font F1 (Helvetica)
    // Obj 4: Font F2 (Helvetica-Bold)
    // Then for each page i:
    //   Obj (5 + 2*i): Page
    //   Obj (6 + 2*i): Content Stream
    final pageCount = _pageStreams.length;
    final totalObjects = 4 + (pageCount * 2);

    void recordOffset() {
      offsets.add(buffer.length);
    }

    // 1 0 obj: Catalog
    recordOffset();
    writeString('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // 2 0 obj: Pages
    recordOffset();
    final kids = StringBuffer();
    for (int i = 0; i < pageCount; i++) {
      final pageObjId = 5 + (i * 2);
      kids.write('$pageObjId 0 R ');
    }
    writeString('2 0 obj\n<< /Type /Pages /Kids [ $kids] /Count $pageCount >>\nendobj\n');

    // 3 0 obj: Font F1 (Helvetica)
    recordOffset();
    writeString('3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n');

    // 4 0 obj: Font F2 (Helvetica-Bold)
    recordOffset();
    writeString('4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\nendobj\n');

    // Page and Stream objects
    for (int i = 0; i < pageCount; i++) {
      final pageObjId = 5 + (i * 2);
      final streamObjId = pageObjId + 1;
      final streamBytes = utf8.encode(_pageStreams[i]);

      // Page Object
      recordOffset();
      writeString(
        '$pageObjId 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${PdfExportService.a4Width} ${PdfExportService.a4Height}] '
        '/Contents $streamObjId 0 R /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> >>\nendobj\n',
      );

      // Stream Object
      recordOffset();
      writeString('$streamObjId 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n');
      buffer.add(streamBytes);
      writeString('\nendstream\nendobj\n');
    }

    // Cross-Reference Table (xref)
    final startXref = buffer.length;
    writeString('xref\n0 ${totalObjects + 1}\n');
    writeString('0000000000 65535 f \n');
    for (final offset in offsets) {
      final padded = offset.toString().padLeft(10, '0');
      writeString('$padded 00000 n \n');
    }

    // Trailer
    writeString('trailer\n<< /Size ${totalObjects + 1} /Root 1 0 R >>\n');
    writeString('startxref\n$startXref\n%%EOF\n');

    return buffer.toBytes();
  }
}
