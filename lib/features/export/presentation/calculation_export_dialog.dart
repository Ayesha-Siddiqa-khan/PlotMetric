import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/calculation.dart';
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
  String? _lastSavedFilePath;
  bool _showCustomHeaders = false;

  late final TextEditingController _subtitleController;
  late final TextEditingController _metadataController;
  late final TextEditingController _summaryTitleController;
  late final TextEditingController _totalAreaLabelController;
  late final TextEditingController _totalDeductionsLabelController;
  late final TextEditingController _netBalanceLabelController;

  @override
  void initState() {
    super.initState();
    _subtitleController = TextEditingController(text: 'LAND MEASUREMENT & COLONY DEDUCTION REPORT');
    final nowStr = DateTime.now().toLocal().toString().split('.').first;
    _metadataController = TextEditingController(
      text: 'Generated on: $nowStr | 1 Kanal = 20 Marlas, 1 Marla = 9 Sarsais (272.25 sq ft)',
    );
    _summaryTitleController = TextEditingController(text: 'SUMMARY & NET REMAINING BALANCE');
    _totalAreaLabelController = TextEditingController(text: 'Total Colony Area (+)');
    _totalDeductionsLabelController = TextEditingController(text: 'Total Deductions (Roads/Parks/Mosque) (-)');
    _netBalanceLabelController = TextEditingController(text: 'NET REMAINING BALANCE');
  }

  @override
  void dispose() {
    _subtitleController.dispose();
    _metadataController.dispose();
    _summaryTitleController.dispose();
    _totalAreaLabelController.dispose();
    _totalDeductionsLabelController.dispose();
    _netBalanceLabelController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf({bool share = false}) async {
    setState(() => _isProcessing = true);
    try {
      final bytes = PdfExportService.generateCalculationPdf(
        widget.calculation,
        subtitle: _subtitleController.text,
        metadataLine: _metadataController.text,
        summaryTitle: _summaryTitleController.text,
        totalAreaLabel: _totalAreaLabelController.text,
        totalDeductionsLabel: _totalDeductionsLabelController.text,
        netBalanceLabel: _netBalanceLabelController.text,
      );
      final rawTitle = widget.calculation.title.trim().isEmpty ? 'Colony_Report' : widget.calculation.title.trim();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = '${rawTitle}_$timestamp.pdf';

      final result = await FileSaveHelper.saveBinaryFile(fileName: fileName, bytes: bytes);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _lastSavedFilePath = result.filePath;
          _statusMessage = 'PDF saved: ${result.fileName}';
        });
        if (share) {
          if (!kIsWeb && Platform.isAndroid) {
            final shared = await FileSaveHelper.shareFile(
              result.filePath,
              mimeType: 'application/pdf',
              title: 'Share PDF via WhatsApp',
              preferWhatsApp: true,
            );
            if (mounted && !shared) {
              setState(() => _statusMessage = 'Could not open Android sharing. PDF saved as ${result.fileName}.');
            }
          } else {
            await FileSaveHelper.openFolder(result.filePath);
            if (mounted) {
              setState(() => _statusMessage = 'Attach ${result.fileName} in WhatsApp.');
            }
          }
        } else {
          await FileSaveHelper.openFile(result.filePath);
        }
      } else {
        setState(() => _statusMessage = result.errorMessage ?? 'Failed to save PDF');
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Error generating PDF: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportWord() async {
    setState(() => _isProcessing = true);
    try {
      final content = WordExporter.exportCalculation(
        widget.calculation,
        subtitle: _subtitleController.text,
        metadataLine: _metadataController.text,
        summaryTitle: _summaryTitleController.text,
        totalAreaLabel: _totalAreaLabelController.text,
        totalDeductionsLabel: _totalDeductionsLabelController.text,
        netBalanceLabel: _netBalanceLabelController.text,
      );
      final rawTitle = widget.calculation.title.trim().isEmpty ? 'Colony_Report' : widget.calculation.title.trim();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = '${rawTitle}_$timestamp.doc';

      final result = await FileSaveHelper.saveTextFile(fileName: fileName, content: content);
      if (result.success) {
        setState(() {
          _lastSavedFilePath = result.filePath;
          _statusMessage = 'Word document (.doc) saved: ${result.fileName}';
        });
        await FileSaveHelper.openFile(result.filePath);
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
        setState(() {
          _lastSavedFilePath = result.filePath;
          _statusMessage = 'CSV spreadsheet saved: ${result.fileName}';
        });
        await FileSaveHelper.openFile(result.filePath);
      } else {
        setState(() => _statusMessage = result.errorMessage ?? 'Failed to save CSV');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error exporting CSV: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.calculation.title.isEmpty ? '(Untitled Scheme)' : widget.calculation.title;
    final summary = widget.calculation.summary;

    return AlertDialog(
      scrollable: true,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Net Balance:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${summary.netCompositeArea.toDisplayString()} (${summary.netSqFtFormatted} sq ft)',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryNavy),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Optional Customizable Headers & Summary Accordion/Toggle
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
                      'Customize Report',
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
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppTheme.dividerColor),
              const SizedBox(height: 6),
              const Text(
                'Customize Summary & Balance Box Labels:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _summaryTitleController,
                decoration: const InputDecoration(
                  labelText: 'Summary Box Title',
                  hintText: 'e.g. SUMMARY & NET REMAINING BALANCE',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _totalAreaLabelController,
                decoration: const InputDecoration(
                  labelText: 'Total Colony / Gross Area Label',
                  hintText: 'e.g. Total Colony Area (+)',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _totalDeductionsLabelController,
                decoration: const InputDecoration(
                  labelText: 'Total Deductions Label',
                  hintText: 'e.g. Total Deductions (Roads/Parks/Mosque) (-)',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _netBalanceLabelController,
                decoration: const InputDecoration(
                  labelText: 'Net Remaining Balance Label',
                  hintText: 'e.g. NET REMAINING BALANCE',
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
              // Action Buttons (Compact with icons)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('A4 PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _exportPdf(share: true),
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportWord,
                      icon: const Icon(Icons.description, size: 16, color: Color(0xFF185ABD)),
                      label: const Text('Word (.doc)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF185ABD))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        side: const BorderSide(color: Color(0xFF185ABD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportCsv,
                      icon: const Icon(Icons.table_chart, size: 16, color: Color(0xFF107C41)),
                      label: const Text('Excel / CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF107C41))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        side: const BorderSide(color: Color(0xFF107C41)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),

              if (_lastSavedFilePath != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final opened = await FileSaveHelper.openFile(_lastSavedFilePath!);
                          if (!opened && mounted) {
                            setState(() => _statusMessage = 'No viewer could open this file.');
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open File', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final shared = await FileSaveHelper.shareFile(_lastSavedFilePath!);
                          if (!shared && mounted) {
                            setState(() => _statusMessage = 'Could not open sharing for this file.');
                          }
                        },
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share File', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!kIsWeb && (!Platform.isAndroid || _lastSavedFilePath!.startsWith('content://')))
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Open Folder'),
                    onPressed: () async {
                      final opened = await FileSaveHelper.openFolder(_lastSavedFilePath!);
                      if (!opened && mounted) {
                        setState(() => _statusMessage = 'Could not open the export folder.');
                      }
                    },
                  ),
              ],
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
