import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/calculation.dart';
import '../../land/logic/land_math.dart';
import '../logic/csv_exporter.dart';
import '../logic/file_save_helper.dart';
import '../logic/pdf_export_service.dart';
import '../logic/word_exporter.dart';

class CalculationExportDialog extends StatefulWidget {
  final Calculation calculation;

  const CalculationExportDialog({super.key, required this.calculation});

  static Future<void> show(BuildContext context, Calculation calculation) {
    return showDialog(
      context: context,
      builder: (ctx) => CalculationExportDialog(calculation: calculation),
    );
  }

  @override
  State<CalculationExportDialog> createState() => _CalculationExportDialogState();
}

class _CalculationExportDialogState extends State<CalculationExportDialog> {
  bool _isProcessing = false;
  String? _statusMessage;
  String? _lastSavedPdfPath;
  bool _showCustomHeaders = false;

  late final TextEditingController _subtitleController;
  late final TextEditingController _metadataController;

  @override
  void initState() {
    super.initState();
    _subtitleController = TextEditingController(text: 'LAND MEASUREMENT & COLONY DEDUCTION REPORT');
    final nowStr = DateTime.now().toLocal().toString().split('.').first;
    _metadataController = TextEditingController(
      text: 'Generated on: $nowStr | 1 Kanal = 20 Marlas, 1 Marla = 9 Sarsais (272.25 sq ft)',
    );
  }

  @override
  void dispose() {
    _subtitleController.dispose();
    _metadataController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = PdfExportService.generateCalculationPdf(
        widget.calculation,
        subtitle: _subtitleController.text,
        metadataLine: _metadataController.text,
      );
      final rawTitle = widget.calculation.title.trim().isEmpty ? 'Colony_Report' : widget.calculation.title.trim();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = '${rawTitle}_$timestamp.pdf';

      final result = await FileSaveHelper.saveBinaryFile(fileName: fileName, bytes: bytes);
      if (result.success) {
        setState(() {
          _lastSavedPdfPath = result.filePath;
          _statusMessage = 'PDF successfully generated & saved:\n${result.filePath}';
        });
      } else {
        setState(() => _statusMessage = result.errorMessage ?? 'Failed to save PDF');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error generating PDF: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportWord() async {
    setState(() => _isProcessing = true);
    try {
      final content = WordExporter.exportCalculation(
        widget.calculation,
        subtitle: _subtitleController.text,
        metadataLine: _metadataController.text,
      );
      final rawTitle = widget.calculation.title.trim().isEmpty ? 'Colony_Report' : widget.calculation.title.trim();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = '${rawTitle}_$timestamp.doc';

      final result = await FileSaveHelper.saveTextFile(fileName: fileName, content: content);
      if (result.success) {
        setState(() => _statusMessage = 'Word document (.doc) saved:\n${result.filePath}');
      } else {
        setState(() => _statusMessage = result.errorMessage ?? 'Failed to save Word document');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error exporting Word: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isProcessing = true);
    try {
      final content = CsvExporter.exportCalculation(widget.calculation);
      final rawTitle = widget.calculation.title.trim().isEmpty ? 'Colony_Report' : widget.calculation.title.trim();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = '${rawTitle}_$timestamp.csv';

      final result = await FileSaveHelper.saveTextFile(fileName: fileName, content: content);
      if (result.success) {
        setState(() => _statusMessage = 'CSV spreadsheet saved:\n${result.filePath}');
      } else {
        setState(() => _statusMessage = result.errorMessage ?? 'Failed to save CSV');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error exporting CSV: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _shareViaWhatsApp() {
    final summary = widget.calculation.summary;

    final deductionsList = <Map<String, String>>[];
    for (final e in widget.calculation.entries) {
      if (e.isSubtract) {
        final centi = LandMath.rowToCentiSarsai(kanal: e.kanal, marla: e.marla, sarsaiCenti: e.sarsaiCenti);
        final area = LandMath.centiSarsaiToCompositeArea(centi);
        final sqFt = LandMath.centiSarsaiToSquareFeet(centi).toStringAsFixed(1);
        deductionsList.add({
          'name': e.purpose.isEmpty ? 'Deduction' : e.purpose,
          'area': area.toDisplayString(),
          'sqFt': sqFt,
        });
      }
    }

    final message = FileSaveHelper.formatWhatsAppSummary(
      title: widget.calculation.title,
      totalArea: '${summary.totalAddCompositeArea.toDisplayString()} (${summary.totalAddSqFtFormatted} sq ft)',
      totalDeductions: '${summary.totalSubtractCompositeArea.toDisplayString()} (${summary.totalSubtractSqFtFormatted} sq ft)',
      netBalance: summary.netCompositeArea.toDisplayString(),
      netSqFt: summary.netSqFtFormatted,
      deductions: deductionsList,
      localFilePath: _lastSavedPdfPath,
    );

    FileSaveHelper.shareViaWhatsApp(message);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp share text prepared and copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.calculation.title.isEmpty ? '(Untitled Scheme)' : widget.calculation.title;
    final summary = widget.calculation.summary;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: AppTheme.primaryNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Export & Share: $title',
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overview summary bar
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.paleBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Entries:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text('${widget.calculation.entries.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Net Balance:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text(
                        '${summary.netCompositeArea.toDisplayString()} (${summary.netSqFtFormatted} sq ft)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Optional Customizable Headers Accordion/Toggle
            InkWell(
              onTap: () => setState(() => _showCustomHeaders = !_showCustomHeaders),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _showCustomHeaders ? Icons.tune : Icons.tune_outlined,
                      size: 16,
                      color: AppTheme.accentTeal,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Customize Header & Subtitle (Optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showCustomHeaders ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_showCustomHeaders) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Document Subtitle',
                  hintText: 'e.g. LAND MEASUREMENT & COLONY DEDUCTION REPORT',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _metadataController,
                decoration: const InputDecoration(
                  labelText: 'Date & Units Note (Header Subtitle 2)',
                  hintText: 'e.g. Generated on: ... | 1 Kanal = 20 Marlas...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 10),

            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(fontSize: 11, color: Colors.green.shade900),
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_isProcessing)
              const Center(child: Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(color: AppTheme.accentTeal),
              ))
            else ...[
              // Action Buttons
              ElevatedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Generate Black & White A4 PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),

              if (_lastSavedPdfPath != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => FileSaveHelper.openFile(_lastSavedPdfPath!),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Open / Print PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => FileSaveHelper.openFolder(_lastSavedPdfPath!),
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Show in Folder'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              ElevatedButton.icon(
                onPressed: _shareViaWhatsApp,
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('Share Breakdown via WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportWord,
                      icon: const Icon(Icons.description, size: 16),
                      label: const Text('Export Word (.doc)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportCsv,
                      icon: const Icon(Icons.table_chart, size: 16),
                      label: const Text('Export CSV'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
