import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/land_units.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/number_formatters.dart';
import '../../../data/models/calculation.dart';
import '../../../data/models/measurement_entry.dart';
import '../../export/presentation/calculation_export_dialog.dart';
import '../../land/logic/land_math.dart';
import '../../land/state/land_controller.dart';
import '../logic/land_document_parser.dart';

class ScanScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToLand;

  const ScanScreen({super.key, required this.onNavigateToLand});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final TextEditingController _documentTextController = TextEditingController();
  final TextEditingController _schemeTitleController = TextEditingController(text: 'Imported Plan');
  List<ParsedMeasurementItem> _extractedItems = [];
  bool _hasParsed = false;
  String? _previewImagePath;
  bool _isOcrProcessing = false;

  static const String _defaultSample = '''Ittefaq City Housing Scheme Plan
Total Area: 500 Kanal, 0 Marla, 0 Sarsai
Roads Deduction: 20 Kanal, 5 Marla, 2 Sarsai
Sewerage & Disposal: 3 Kanal, 10 Marla
Central Mosque: 1 Kanal, 0 Marla
Public Parks: 15 Kanal, 8 Marla
Graveyard: 5 Kanal, 0 Marla
Commercial Zone: 25 Kanal, 0 Marla''';

  @override
  void dispose() {
    _documentTextController.dispose();
    _schemeTitleController.dispose();
    super.dispose();
  }

  void _loadSampleDocument() {
    _documentTextController.text = _defaultSample;
    _schemeTitleController.text = 'Ittefaq City';
    _parseCurrentText();
  }

  void _parseCurrentText() {
    final text = _documentTextController.text;
    final parsed = LandDocumentParser.parseDocumentText(text);
    setState(() {
      _extractedItems = parsed;
      _hasParsed = true;
    });

    if (parsed.isEmpty && text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recognized Kanal/Marla/Sarsai figures found in the text.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  void _addNewManualItem() {
    setState(() {
      _extractedItems.add(
        ParsedMeasurementItem(
          operation: EntryOperation.add,
          purpose: 'Nil',
          kanal: 0,
          marla: 0,
          sarsaiCenti: 0,
        ),
      );
      _hasParsed = true;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _extractedItems.removeAt(index);
    });
  }

  void _sendToLandCalculator() {
    if (_extractedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No measurement items to send. Please add or extract at least one item.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final entries = <MeasurementEntry>[];
    for (int i = 0; i < _extractedItems.length; i++) {
      final item = _extractedItems[i];
      entries.add(
        MeasurementEntry(
          sortOrder: i,
          purpose: item.purpose.trim().isEmpty ? 'Nil' : item.purpose.trim(),
          operation: item.operation,
          kanal: item.kanal,
          marla: item.marla,
          sarsaiCenti: item.sarsaiCenti,
        ),
      );
    }

    final landCtrl = ref.read(landControllerProvider);
    landCtrl.importMeasurements(
      title: _schemeTitleController.text,
      entries: entries,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transferred ${entries.length} measurements to Land Calculator!'),
        backgroundColor: AppTheme.accentTeal,
        duration: const Duration(seconds: 2),
      ),
    );

    widget.onNavigateToLand();
  }

  void _openExportDialog() {
    if (_extractedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No measurement items to export. Please extract or add items first.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final entries = <MeasurementEntry>[];
    for (int i = 0; i < _extractedItems.length; i++) {
      final item = _extractedItems[i];
      entries.add(
        MeasurementEntry(
          sortOrder: i,
          purpose: item.purpose.trim().isEmpty ? 'Nil' : item.purpose.trim(),
          operation: item.operation,
          kanal: item.kanal,
          marla: item.marla,
          sarsaiCenti: item.sarsaiCenti,
        ),
      );
    }

    final now = DateTime.now();
    final dateIso = now.toIso8601String().split('T').first;
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final title = _schemeTitleController.text.trim().isEmpty
        ? 'Scanned Document Report'
        : _schemeTitleController.text.trim();

    final calculation = Calculation(
      title: title,
      calculationDate: dateIso,
      calculationTime: timeStr,
      createdAtUtc: now.toUtc().toIso8601String(),
      updatedAtUtc: now.toUtc().toIso8601String(),
      entries: entries,
    );

    CalculationExportDialog.show(context, calculation);
  }

  Future<void> _chooseImageOrDocument() async {
    try {
      if (Platform.isWindows) {
        final script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Select Document or Image to Scan'
$dialog.Filter = 'Supported Files (*.png;*.jpg;*.jpeg;*.txt;*.csv)|*.png;*.jpg;*.jpeg;*.txt;*.csv|Images (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg|Text Documents (*.txt;*.csv)|*.txt;*.csv|All Files (*.*)|*.*'
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Write-Output $dialog.FileName
}
''';
        final result = await Process.run('powershell', ['-NoProfile', '-Command', script]);
        final selectedPath = result.stdout.toString().trim();
        if (selectedPath.isNotEmpty && File(selectedPath).existsSync()) {
          await _processPickedFile(selectedPath);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }

  Future<void> _processPickedFile(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    if (ext == 'txt' || ext == 'csv') {
      try {
        final text = await File(filePath).readAsString();
        setState(() {
          _previewImagePath = null;
          _documentTextController.text = text;
        });
        _parseCurrentText();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded document: ${filePath.split('\\').last}'),
              backgroundColor: AppTheme.accentTeal,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reading text file: $e')),
          );
        }
      }
    } else if (['png', 'jpg', 'jpeg', 'bmp'].contains(ext)) {
      setState(() {
        _previewImagePath = filePath;
        _isOcrProcessing = true;
      });

      String ocrText = '';
      try {
        final escaped = filePath.replaceAll("'", "''");
        final ocrScript = '''
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null

\$file = [Windows.Storage.StorageFile]::GetFileFromPathAsync('$escaped').GetAwaiter().GetResult()
\$stream = \$file.OpenAsync([Windows.Storage.FileAccessMode]::Read).GetAwaiter().GetResult()
\$decoder = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync(\$stream).GetAwaiter().GetResult()
\$softwareBitmap = \$decoder.GetSoftwareBitmapAsync().GetAwaiter().GetResult()
\$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
if (\$engine) {
    \$ocrResult = \$engine.RecognizeAsync(\$softwareBitmap).GetAwaiter().GetResult()
    Write-Output \$ocrResult.Text
}
''';
        final ocrProcess = await Process.run('powershell', ['-NoProfile', '-Command', ocrScript]);
        ocrText = ocrProcess.stdout.toString().trim();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isOcrProcessing = false;
          if (ocrText.isNotEmpty) {
            _documentTextController.text = ocrText;
          }
        });

        if (ocrText.isNotEmpty) {
          _parseCurrentText();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document OCR scan complete! Measurements extracted.'),
              backgroundColor: AppTheme.accentTeal,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image loaded for visual review. You can paste or type document figures.'),
              backgroundColor: AppTheme.primaryNavy,
            ),
          );
        }
      }
    }
  }

  Future<void> _takePhotoOrScan() async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', 'microsoft.windows.camera:'], runInShell: true);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.camera_alt, color: AppTheme.primaryNavy),
                  SizedBox(width: 8),
                  Text('Camera Opened'),
                ],
              ),
              content: const Text(
                'Windows Camera has opened.\n\n'
                '1. Capture or snapshot your document.\n'
                '2. Click "Choose Captured Image" to select and OCR scan it.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _chooseImageOrDocument();
                  },
                  icon: const Icon(Icons.photo_library, size: 16),
                  label: const Text('Choose Captured Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        _chooseImageOrDocument();
      }
    } catch (_) {
      _chooseImageOrDocument();
    }
  }

  LandWorksheetSummary _computeExtractionSummary() {
    final rows = _extractedItems.map((e) {
      return (isSubtract: e.isSubtract, centiSarsai: e.centiSarsai);
    }).toList();
    return LandMath.computeSummary(rows);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _computeExtractionSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR & Document Scanner'),
        actions: [
          if (_extractedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export & Share PDF / Word / CSV',
              onPressed: _openExportDialog,
            ),
          TextButton.icon(
            onPressed: _loadSampleDocument,
            icon: const Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
            label: const Text(
              'Sample Plan',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title / Ingestion Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.document_scanner, color: AppTheme.primaryNavy, size: 28),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Document OCR & Measurement Ingestion',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Scan or import mutation documents, colony deduction plans, or deed text. '
                          'The engine automatically detects Kanal, Marla, Sarsai and labels for mandatory review.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 14),
                        // Action buttons row
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _takePhotoOrScan,
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Take Photo / Scan'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _chooseImageOrDocument,
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: const Text('Choose Image / File'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _loadSampleDocument,
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text('Load Scheme Sample'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentTeal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (_isOcrProcessing) ...[
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentTeal),
                              ),
                              SizedBox(width: 8),
                              Text('Running Windows OCR text extraction on image...', style: TextStyle(fontSize: 12, color: AppTheme.accentTeal)),
                            ],
                          ),
                        ],
                        if (_previewImagePath != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.paleBackground,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.dividerColor),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.file(
                                    File(_previewImagePath!),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Selected Image:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      Text(
                                        _previewImagePath!.split('\\').last,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavy),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Clear image',
                                  onPressed: () => setState(() => _previewImagePath = null),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        // Raw text input area
                        TextField(
                          controller: _documentTextController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Document Text / OCR Output',
                            hintText: 'Paste or type document text (e.g. "Total Area: 500 Kanal, Roads: 20-5-2")...',
                            filled: true,
                            fillColor: AppTheme.paleBackground,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _documentTextController.clear();
                                setState(() {
                                  _extractedItems.clear();
                                  _hasParsed = false;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _parseCurrentText,
                            icon: const Icon(Icons.analytics_outlined, size: 18),
                            label: const Text('Extract Measurements'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_hasParsed || _extractedItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Mandatory Review & Correction Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.rule, color: AppTheme.accentTeal),
                                  SizedBox(width: 8),
                                  Text(
                                    'Mandatory Review & Correction',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryNavy,
                                    ),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: _addNewManualItem,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Line'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Verify each extracted figure before transferring to the Land Calculator. '
                            'Tap the sign (+ / −) to toggle operation, or edit values directly.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 12),
                          // Calculation Title field
                          TextField(
                            controller: _schemeTitleController,
                            decoration: const InputDecoration(
                              labelText: 'Target Calculation Title',
                              hintText: 'e.g. Ittefaq City Housing Scheme Plan',
                              prefixIcon: Icon(Icons.label_outline, size: 18),
                              isDense: true,
                            ),
                            onTap: () {
                              if (_schemeTitleController.text == 'Imported Plan' || _schemeTitleController.text.isEmpty) {
                                _schemeTitleController.clear();
                              } else {
                                _schemeTitleController.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _schemeTitleController.text.length,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppTheme.dividerColor),
                          const SizedBox(height: 8),

                          // Extracted items list
                          if (_extractedItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No items extracted yet. Paste text or click "Load Scheme Sample".',
                                  style: TextStyle(color: AppTheme.textMuted),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _extractedItems.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF0F4F8)),
                              itemBuilder: (context, i) {
                                final item = _extractedItems[i];
                                return _buildExtractedItemRow(i, item);
                              },
                            ),

                          const SizedBox(height: 14),
                          // Live Summary of Extracted Items
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F8F6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net Extracted Area:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        summary.netCompositeArea.toDisplayString(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net Square Feet:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '${summary.netSqFtFormatted} sq ft',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentTeal),
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Actions: Send to Land Calculator & Export / Print Report
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  onPressed: _sendToLandCalculator,
                                  icon: const Icon(Icons.send_rounded, size: 18),
                                  label: const Text(
                                    'Send to Land Calculator',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentTeal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: OutlinedButton.icon(
                                  onPressed: _openExportDialog,
                                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                                  label: const Text(
                                    'Export / Print PDF',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryNavy,
                                    side: const BorderSide(color: AppTheme.primaryNavy, width: 1.2),
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  // Privacy & Security Guarantee Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: AppTheme.accentTeal),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Offline & Privacy Guarantee: Text extraction and parsing run 100% on-device. No document text or land records are ever transmitted over the network.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractedItemRow(int index, ParsedMeasurementItem item) {
    final isSubtract = item.isSubtract;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    if (isNarrow) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _buildSignButton(item, isSubtract),
                const SizedBox(width: 8),
                Expanded(child: _buildPurposeField(item)),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppTheme.dangerRed),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove entry',
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildKanalField(item),
                const SizedBox(width: 4),
                _buildMarlaField(item),
                const SizedBox(width: 4),
                _buildSarsaiField(item),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.sqFtFormatted,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSubtract ? AppTheme.dangerRed : AppTheme.accentTeal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSignButton(item, isSubtract),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _buildPurposeField(item)),
          const SizedBox(width: 6),
          _buildKanalField(item),
          const SizedBox(width: 4),
          _buildMarlaField(item),
          const SizedBox(width: 4),
          _buildSarsaiField(item),
          const SizedBox(width: 8),
          SizedBox(
            width: 85,
            child: Text(
              item.sqFtFormatted,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSubtract ? AppTheme.dangerRed : AppTheme.accentTeal,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppTheme.dangerRed),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove entry',
            onPressed: () => _removeItem(index),
          ),
        ],
      ),
    );
  }

  Widget _buildSignButton(ParsedMeasurementItem item, bool isSubtract) {
    return InkWell(
      onTap: () {
        setState(() {
          item.operation = isSubtract ? EntryOperation.add : EntryOperation.subtract;
        });
      },
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

  Widget _buildPurposeField(ParsedMeasurementItem item) {
    return TextFormField(
      initialValue: item.purpose == 'Nil' ? '' : item.purpose,
      decoration: const InputDecoration(
        hintText: 'Nil',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      onChanged: (val) {
        item.purpose = val.trim().isEmpty ? 'Nil' : val;
      },
    );
  }

  Widget _buildKanalField(ParsedMeasurementItem item) {
    return SizedBox(
      width: 58,
      child: TextFormField(
        initialValue: item.kanal == 0 ? '' : item.kanal.toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          hintText: '0',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        onChanged: (val) {
          final k = int.tryParse(val) ?? 0;
          setState(() {
            item.kanal = k <= LandUnits.maxKanal ? k : LandUnits.maxKanal;
          });
        },
      ),
    );
  }

  Widget _buildMarlaField(ParsedMeasurementItem item) {
    return SizedBox(
      width: 50,
      child: TextFormField(
        initialValue: item.marla == 0 ? '' : item.marla.toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          hintText: '0',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        onChanged: (val) {
          final m = int.tryParse(val) ?? 0;
          setState(() {
            item.marla = m <= LandUnits.maxMarla ? m : LandUnits.maxMarla;
          });
        },
      ),
    );
  }

  Widget _buildSarsaiField(ParsedMeasurementItem item) {
    return SizedBox(
      width: 56,
      child: TextFormField(
        initialValue: item.sarsaiCenti == 0 ? '' : NumberFormatters.formatSarsaiFromCenti(item.sarsaiCenti),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          hintText: '0',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        onChanged: (val) {
          final s = NumberFormatters.parseSarsaiToCenti(val) ?? 0;
          setState(() {
            item.sarsaiCenti = s <= LandUnits.maxSarsaiCenti ? s : LandUnits.maxSarsaiCenti;
          });
        },
      ),
    );
  }
}
