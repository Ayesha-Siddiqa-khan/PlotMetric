import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/utils/native_platform_helper.dart';
import '../hocr.dart';
import '../ocr_models.dart';
import '../ocr_provider.dart';

/// Tesseract 4 (LSTM) on Android, through the `tesseract_ocr` plugin's native channel. Offline.
///
/// The plugin's Dart API only returns plain text, which has no positions, so this adapter asks
/// the plugin's native side for hOCR (word boxes and confidence) directly.
/// The page segmentation mode is fixed to "auto" by the plugin.
class TesseractProvider extends OcrProvider {
  const TesseractProvider();

  static const _channel = MethodChannel('tesseract_ocr');
  static const _configAsset = 'assets/tessdata_config.json';
  static const _dataFolder = 'assets/tessdata';

  @override
  String get id => 'tesseract';
  @override
  String get name => 'Tesseract OCR';
  @override
  String get version => 'Tesseract4Android 4.x LSTM, eng.traineddata';
  @override
  Set<String> get platforms => const {'android'};
  @override
  bool get online => false;

  Future<List<String>> _declaredFiles() async {
    final config =
        jsonDecode(await rootBundle.loadString(_configAsset))
            as Map<String, dynamic>;
    return (config['files'] as List).cast<String>();
  }

  @override
  Future<OcrAvailability> availability() async {
    if (!Platform.isAndroid) {
      return const OcrAvailability.unsupported('Android only');
    }
    try {
      final files = await _declaredFiles();
      if (files.isEmpty) {
        return const OcrAvailability.setupRequired(
          'assets/tessdata_config.json lists no language file.',
        );
      }
      for (final file in files) {
        await rootBundle.load('$_dataFolder/$file');
      }
      return OcrAvailability.ready(
        'Offline, language data: ${files.join(', ')}',
      );
    } catch (_) {
      return const OcrAvailability.setupRequired(
        'Add eng.traineddata to assets/tessdata and list it in assets/tessdata_config.json (see the compatibility report).',
      );
    }
  }

  Future<void> _ensureLanguageData(String documentsDir) async {
    final folder = Directory('$documentsDir/tessdata')
      ..createSync(recursive: true);
    for (final file in await _declaredFiles()) {
      final bytes = (await rootBundle.load(
        '$_dataFolder/$file',
      )).buffer.asUint8List();
      final target = File('${folder.path}/$file');
      if (!target.existsSync() || target.lengthSync() != bytes.length) {
        await target.writeAsBytes(bytes, flush: true);
      }
    }
  }

  @override
  Future<OcrRun> recognize(String imagePath, {OcrCancelToken? cancel}) =>
      runTimed(this, () async {
        final device = await NativePlatformHelper.androidDeviceInfo();
        if (device == null) {
          throw StateError('Tesseract needs the Android app.');
        }
        await _ensureLanguageData(device.documentsDir);
        final hocr = await _channel.invokeMethod<String>('extractHocr', {
          'imagePath': imagePath,
          'tessData': device.documentsDir,
          'language': 'eng',
          'engine': 'tesseract',
        });
        return (
          words: parseHocr(hocr ?? ''),
          rawText: hocr ?? '',
          warnings: const <String>[],
        );
      }, cancel: cancel);
}
