import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class ExportFileResult {
  final bool success;
  final String filePath;
  final String fileName;
  final String? errorMessage;

  const ExportFileResult({
    required this.success,
    this.filePath = '',
    this.fileName = '',
    this.errorMessage,
  });
}

class FileSaveHelper {
  /// Resolves the default export directory for saved PDF, CSV, Word, and Backup files
  static Future<Directory> getExportDirectory() async {
    Directory baseDir;

    if (!kIsWeb && Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        baseDir = Directory(p.join(userProfile, 'Documents', 'PlotMetric_Exports'));
      } else {
        baseDir = Directory(p.join(Directory.current.path, 'plotmetric_exports'));
      }
    } else if (!kIsWeb && (Platform.isLinux || Platform.isMacOS)) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        baseDir = Directory(p.join(home, 'Documents', 'PlotMetric_Exports'));
      } else {
        baseDir = Directory(p.join(Directory.current.path, 'plotmetric_exports'));
      }
    } else {
      // Android / generic fallback
      baseDir = Directory(p.join(Directory.systemTemp.path, 'PlotMetric_Exports'));
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  /// Writes binary bytes (e.g. PDF) to a file in the exports folder
  static Future<ExportFileResult> saveBinaryFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final dir = await getExportDirectory();
      final sanitizedName = _sanitizeFileName(fileName);
      final fullPath = p.join(dir.path, sanitizedName);
      final file = File(fullPath);
      await file.writeAsBytes(bytes, flush: true);

      return ExportFileResult(
        success: true,
        filePath: fullPath,
        fileName: sanitizedName,
      );
    } catch (e) {
      return ExportFileResult(
        success: false,
        errorMessage: 'Failed to write file: $e',
      );
    }
  }

  /// Writes text content (e.g. CSV, HTML/DOC, JSON) to a file in exports folder
  static Future<ExportFileResult> saveTextFile({
    required String fileName,
    required String content,
  }) async {
    try {
      final dir = await getExportDirectory();
      final sanitizedName = _sanitizeFileName(fileName);
      final fullPath = p.join(dir.path, sanitizedName);
      final file = File(fullPath);
      await file.writeAsString(content, flush: true);

      return ExportFileResult(
        success: true,
        filePath: fullPath,
        fileName: sanitizedName,
      );
    } catch (e) {
      return ExportFileResult(
        success: false,
        errorMessage: 'Failed to write file: $e',
      );
    }
  }

  /// Opens the file using the host OS default viewer (e.g. PDF viewer, Word, or text editor)
  static Future<bool> openFile(String filePath) async {
    if (kIsWeb) return false;
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '""', filePath], runInShell: true);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
        return true;
      }
    } catch (_) {
      // Fallback
    }
    return false;
  }

  /// Reveals the file in Windows Explorer or folder browser
  static Future<bool> openFolder(String filePath) async {
    if (kIsWeb) return false;
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
        return true;
      } else if (Platform.isLinux) {
        final parentDir = p.dirname(filePath);
        await Process.run('xdg-open', [parentDir]);
        return true;
      }
    } catch (_) {
      // Fallback
    }
    return false;
  }

  /// Generates a ready-to-share WhatsApp text message summarizing the calculation
  static String formatWhatsAppSummary({
    required String title,
    required String totalArea,
    required String totalDeductions,
    required String netBalance,
    required String netSqFt,
    List<Map<String, String>>? deductions,
    String? localFilePath,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('📋 *PlotMetric - Land Measurement Report*');
    buffer.writeln('🏷️ *Scheme:* ${title.isEmpty ? "(Untitled)" : title}');
    buffer.writeln('📅 *Date:* ${DateTime.now().toLocal().toString().split('.').first}');
    buffer.writeln('-----------------------------------');
    buffer.writeln('➕ *Total Colony Area:* $totalArea');

    if (deductions != null && deductions.isNotEmpty) {
      buffer.writeln('\n➖ *Itemized Deductions:*');
      for (final d in deductions) {
        buffer.writeln('• ${d['name']}: ${d['area']} (${d['sqFt']} sq ft)');
      }
    }

    buffer.writeln('\n-----------------------------------');
    buffer.writeln('➖ *Total Deductions:* $totalDeductions');
    buffer.writeln('✅ *NET REMAINING BALANCE:* $netBalance');
    buffer.writeln('📐 *Square Feet:* $netSqFt sq ft');
    buffer.writeln('-----------------------------------');
    if (localFilePath != null && localFilePath.isNotEmpty) {
      buffer.writeln('📁 *A4 PDF Report Saved at:*');
      buffer.writeln(localFilePath);
    }
    buffer.writeln('Generated with PlotMetric');
    return buffer.toString();
  }

  /// Opens WhatsApp web or desktop app with prefilled text
  static Future<void> shareViaWhatsApp(String text) async {
    final encoded = Uri.encodeComponent(text);
    final url = 'https://api.whatsapp.com/send?text=$encoded';
    if (!kIsWeb && Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '', url], runInShell: true);
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: text));
      }
    } else {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_')
        .trim();
  }
}
