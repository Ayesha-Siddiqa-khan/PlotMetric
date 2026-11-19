import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativePlatformHelper {
  static const MethodChannel _channel = MethodChannel('com.plotmetric.plotmetric/native');

  static Future<String> recognizeImageText(String filePath) async {
    return await _channel.invokeMethod<String>('recognizeImageText', {
      'filePath': filePath,
    }) ?? '';
  }

  static Future<({String reference, String path, String name})> saveAndroidExport(
    String fileName,
    Uint8List bytes,
  ) async {
    final saved = await _channel.invokeMapMethod<String, String>('saveExport', {
      'fileName': fileName,
      'mimeType': _detectMimeType(fileName),
      'bytes': bytes,
    });
    if (saved == null) throw StateError('Android did not return a saved file.');
    return (reference: saved['reference']!, path: saved['path']!, name: saved['name']!);
  }

  /// Shares plain text message using native Android share sheet (WhatsApp, Gmail, Drive, etc.)
  static Future<bool> shareText(String text, {String title = 'Share via'}) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('shareText', {
          'text': text,
          'title': title,
        });
        return res ?? true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Shares a file attachment using native Android share sheet (WhatsApp, Gmail, Drive, etc.)
  static Future<bool> shareFile(String filePath, {String? mimeType, String title = 'Share File', bool preferWhatsApp = false}) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final effectiveMime = mimeType ?? _detectMimeType(filePath);
        final res = await _channel.invokeMethod<bool>('shareFile', {
          'filePath': filePath,
          'mimeType': effectiveMime,
          'title': title,
          'preferWhatsApp': preferWhatsApp,
        });
        return res ?? true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Opens a file in the host OS default viewer (e.g. PDF viewer, Excel, Word, Notepad)
  static Future<bool> openFile(String filePath, {String? mimeType}) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final effectiveMime = mimeType ?? _detectMimeType(filePath);
        final res = await _channel.invokeMethod<bool>('openFile', {
          'filePath': filePath,
          'mimeType': effectiveMime,
        });
        return res ?? true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '""', filePath], runInShell: true);
        return true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', [filePath]);
        return true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [filePath]);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Opens folder in explorer or reveals file in file manager
  static Future<bool> openFolder(String filePath) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('openFolder', {
          'filePath': filePath,
        });
        return res ?? true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', filePath]);
        return true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', ['-R', filePath]);
        return true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isLinux) {
      try {
        final parentDir = File(filePath).parent.path;
        await Process.run('xdg-open', [parentDir]);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Picks an image or document from gallery/storage
  static Future<String?> pickImage() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('pickImage');
        return path;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Captures photo via camera and returns the local file path
  static Future<String?> takePhoto() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('takePhoto');
        return path;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _detectMimeType(String filePath) {
    if (filePath.startsWith('content://')) return '*/*';
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'txt':
        return 'text/plain';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return '*/*';
    }
  }
}
