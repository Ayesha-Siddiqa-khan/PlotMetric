import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../export/logic/csv_exporter.dart';
import '../../export/logic/file_save_helper.dart';
import '../../export/logic/pdf_export_service.dart';
import '../../export/logic/word_exporter.dart';
import '../../info/presentation/land_info_screen.dart';
import '../../land/state/land_controller.dart';
import '../logic/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final repo = ref.read(calculationRepositoryProvider);
  return BackupService(repository: repo);
});

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onDataCleared;

  const SettingsScreen({super.key, this.onDataCleared});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;

  void _showNotification(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppTheme.primaryNavy : AppTheme.dangerRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Backup to JSON ---
  Future<void> _handleBackupJson() async {
    setState(() => _isExporting = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final jsonString = await backupService.exportBackupJson();

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'PlotMetric_Backup_$timestamp.json';

      final result = await FileSaveHelper.saveTextFile(fileName: fileName, content: jsonString);
      if (result.success) {
        _showNotification('Backup successfully created.');
        _showFileResultDialog('Database Backup Created', result, backupText: jsonString);
      } else {
        _showNotification(result.errorMessage ?? 'Failed to save backup.', isSuccess: false);
      }
    } catch (e) {
      _showNotification('Backup error: $e', isSuccess: false);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // --- Restore from JSON ---
  Future<void> _handleRestoreJson() async {
    final textController = TextEditingController();
    final bool? replaceAll = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool replace = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Restore Database'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste the content of your PlotMetric backup JSON file below:',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: textController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: '{\n  "app": "PlotMetric",\n  "calculations": [ ... ]\n}',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: AppTheme.paleBackground,
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Replace all existing records', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('If unchecked, backup records will be appended to existing data', style: TextStyle(fontSize: 11)),
                      value: replace,
                      onChanged: (val) {
                        setDialogState(() {
                          replace = val ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, replace),
                  child: const Text('Restore Now'),
                ),
              ],
            );
          },
        );
      },
    );

    if (replaceAll != null && textController.text.trim().isNotEmpty) {
      setState(() => _isExporting = true);
      try {
        final backupService = ref.read(backupServiceProvider);
        final result = await backupService.restoreFromJson(textController.text.trim(), replaceAll: replaceAll);
        if (result.success) {
          _showNotification(
            'Restored ${result.calculationsCount} calculation(s) and ${result.entriesCount} measurement entries.',
          );
        } else {
          _showNotification(result.errorMessage ?? 'Restore failed', isSuccess: false);
        }
      } catch (e) {
        _showNotification('Restore failed: $e', isSuccess: false);
      } finally {
        setState(() => _isExporting = false);
      }
    }
  }

  // --- Export All Records (PDF, Word, CSV) ---
  Future<void> _handleExportAll(String format) async {
    setState(() => _isExporting = true);
    try {
      final repo = ref.read(calculationRepositoryProvider);
      final calculations = await repo.getAllCalculations();

      if (calculations.isEmpty) {
        _showNotification('No saved records found to export.', isSuccess: false);
        return;
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

      if (format == 'pdf') {
        final bytes = PdfExportService.generateAllCalculationsPdf(calculations);
        final fileName = 'PlotMetric_All_Records_$timestamp.pdf';
        final result = await FileSaveHelper.saveBinaryFile(fileName: fileName, bytes: bytes);
        if (result.success) {
          _showNotification('A4 Black & White PDF exported successfully!');
          _showFileResultDialog('A4 PDF Export Complete', result);
        } else {
          _showNotification(result.errorMessage ?? 'Failed to save PDF.', isSuccess: false);
        }
      } else if (format == 'word') {
        final content = WordExporter.exportCalculations(calculations);
        final fileName = 'PlotMetric_All_Records_$timestamp.doc';
        final result = await FileSaveHelper.saveTextFile(fileName: fileName, content: content);
        if (result.success) {
          _showNotification('Word document (.doc) exported successfully!');
          _showFileResultDialog('Word Document Export Complete', result);
        } else {
          _showNotification(result.errorMessage ?? 'Failed to save Word document.', isSuccess: false);
        }
      } else if (format == 'csv') {
        final content = CsvExporter.exportCalculations(calculations);
        final fileName = 'PlotMetric_All_Records_$timestamp.csv';
        final result = await FileSaveHelper.saveTextFile(fileName: fileName, content: content);
        if (result.success) {
          _showNotification('CSV spreadsheet exported successfully!');
          _showFileResultDialog('CSV Export Complete', result);
        } else {
          _showNotification(result.errorMessage ?? 'Failed to save CSV.', isSuccess: false);
        }
      }
    } catch (e) {
      _showNotification('Export error: $e', isSuccess: false);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // --- Clear All Data ---
  Future<void> _handleClearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed),
            SizedBox(width: 8),
            Text('Clear All Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all saved calculations, housing colony sheets, and measurement entries from your local SQLite database.\n\nAre you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isExporting = true);
      try {
        final backupService = ref.read(backupServiceProvider);
        final count = await backupService.clearAllData();
        widget.onDataCleared?.call();
        _showNotification('Cleared all database records ($count items removed).');
      } catch (e) {
        _showNotification('Failed to clear data: $e', isSuccess: false);
      } finally {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showFileResultDialog(String title, ExportFileResult file, {String? backupText, String? feedback}) {
    final filePath = file.filePath;
    final fileName = file.fileName;
    final displayPath = file.displayPath ?? filePath;
    final isDownloads = filePath.startsWith('content://');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void showFeedback(String message) {
            if (dialogContext.mounted) setDialogState(() => feedback = message);
          }

          return AlertDialog(
            scrollable: true,
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: $fileName', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (isDownloads) const Text('Downloads / PlotMetric_Exports'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.paleBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: SelectableText(displayPath, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ),
                const SizedBox(height: 12),
                if (feedback != null) Text(feedback!, style: const TextStyle(fontSize: 12)),
              ],
            ),
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share (WhatsApp/Drive)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (!await FileSaveHelper.shareFile(filePath, title: 'Share $fileName')) {
                    showFeedback('Could not open sharing for this file.');
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (backupText != null && !kIsWeb && Platform.isAndroid) {
                    await _showBackupText(dialogContext, fileName, backupText);
                  } else if (!await FileSaveHelper.openFile(filePath)) {
                    showFeedback('No viewer could open this file.');
                  }
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Path'),
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: displayPath));
                    showFeedback('File path copied to clipboard.');
                  } catch (_) {
                    showFeedback('Could not copy the file path.');
                  }
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Open Folder'),
                onPressed: () async {
                  if (await FileSaveHelper.openFolder(filePath)) return;
                  if (!kIsWeb && Platform.isAndroid && !isDownloads && dialogContext.mounted) {
                    try {
                      await _showPrivateExportFolder(dialogContext, File(filePath).parent);
                    } on FileSystemException {
                      showFeedback('Could not read the export folder.');
                    }
                  } else {
                    showFeedback('Open Downloads / PlotMetric_Exports in your file manager.');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showBackupText(BuildContext context, String name, String text) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: Text(name),
      content: SelectableText(text, style: const TextStyle(fontFamily: 'monospace')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );

  Future<void> _showPrivateExportFolder(BuildContext context, Directory directory) async {
    final files = await directory.list().where((entry) => entry is File).cast<File>().toList();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('PlotMetric Exports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final file in files) ListTile(
            title: Text(Uri.file(file.path).pathSegments.last),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              Navigator.pop(ctx);
              final name = Uri.file(file.path).pathSegments.last;
              final isBackup = name.toLowerCase().endsWith('.json');
              String? backup;
              try {
                if (isBackup) backup = await file.readAsString();
              } on FileSystemException {
                if (mounted) _showNotification('Could not read this backup.', isSuccess: false);
                return;
              }
              if (!mounted) return;
              _showFileResultDialog('Exported File', ExportFileResult(
                success: true, filePath: file.path, fileName: name,
              ), backupText: backup);
            },
          )],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Data Management'),
      ),
      body: SafeArea(
        child: _isExporting
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accentTeal),
                    SizedBox(height: 16),
                    Text('Processing data, please wait...'),
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Backup & Restore Card
                      _buildSectionCard(
                        title: 'Database Backup & Restore',
                        icon: Icons.backup_outlined,
                        children: [
                          const Text(
                            'Safeguard your land measurements and housing scheme data by saving an offline JSON backup or restoring from a previous backup file.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _handleBackupJson,
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Backup to JSON'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryNavy,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  setState(() => _isExporting = true);
                                  try {
                                    final backupService = ref.read(backupServiceProvider);
                                    final jsonString = await backupService.exportBackupJson();
                                    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
                                    final fileName = 'PlotMetric_Backup_$timestamp.json';
                                    final result = await FileSaveHelper.saveTextFile(fileName: fileName, content: jsonString);
                                    if (result.success) {
                                      final shared = await FileSaveHelper.shareFile(result.filePath, title: 'Share Database Backup via WhatsApp / Drive');
                                      if (!shared && mounted) {
                                        _showFileResultDialog('Database Backup Created', result, backupText: jsonString, feedback: 'Could not open sharing for this file.');
                                      }
                                    } else {
                                      _showNotification('Failed to generate backup: ${result.errorMessage}', isSuccess: false);
                                    }
                                  } catch (e) {
                                    _showNotification('Error sharing backup: $e', isSuccess: false);
                                  } finally {
                                    setState(() => _isExporting = false);
                                  }
                                },
                                icon: const Icon(Icons.share, size: 18),
                                label: const Text('Share Backup (WhatsApp/Drive)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _handleRestoreJson,
                                icon: const Icon(Icons.upload, size: 18),
                                label: const Text('Restore from JSON'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Export Formats Card
                      _buildSectionCard(
                        title: 'Export All Records',
                        icon: Icons.file_download_outlined,
                        children: [
                          const Text(
                            'Export your entire database of land calculations in your chosen format. All outputs adhere to standard A4 printing and centralized tabular formatting.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _handleExportAll('pdf'),
                                icon: const Icon(Icons.picture_as_pdf, size: 18),
                                label: const Text('Export PDF (Black & White A4)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _handleExportAll('word'),
                                icon: const Icon(Icons.description, size: 18),
                                label: const Text('Export Word (.doc)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF185ABD),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _handleExportAll('csv'),
                                icon: const Icon(Icons.table_chart, size: 18),
                                label: const Text('Export CSV (Excel)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF107C41),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Data Management / Clear All
                      _buildSectionCard(
                        title: 'Data Management',
                        icon: Icons.delete_sweep_outlined,
                        children: [
                          const Text(
                            'Clear all saved calculations and measurement entries from the local database. Warning: This action cannot be undone.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _handleClearAllData,
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text('Clear All Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.dangerRed,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Standards & Measurement Units Info
                      _buildSectionCard(
                        title: 'Land Units & Standards',
                        icon: Icons.straighten,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LandInfoScreen()),
                              );
                            },
                            icon: const Icon(Icons.menu_book, size: 18),
                            label: const Text('Open Complete Land & Revenue Guide'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildUnitRow('1 Karam', '5.5 Feet (66 Inches)'),
                          _buildUnitRow('1 Sarsai', '1 Karam × 1 Karam = 30.25 Sq Ft'),
                          _buildUnitRow('1 Marla', '9 Sarsais = 272.25 Sq Ft'),
                          _buildUnitRow('1 Kanal', '20 Marlas = 180 Sarsais = 5,445 Sq Ft'),
                          _buildUnitRow('1 Acre / Qila', '8 Kanals = 160 Marlas = 43,560 Sq Ft'),
                          _buildUnitRow('1 Murabba', '25 Acres = 200 Kanals = 1,089,000 Sq Ft'),
                          const Divider(height: 16),
                          const Text(
                            'PlotMetric Version 1.0.0+1 (Offline First, Pure Integer Centi-Sarsai Engine)',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryNavy),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppTheme.dividerColor),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildUnitRow(String unit, String definition) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              unit,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
          ),
          Expanded(
            child: Text(
              definition,
              style: const TextStyle(fontSize: 12, color: AppTheme.charcoalText),
            ),
          ),
        ],
      ),
    );
  }
}
