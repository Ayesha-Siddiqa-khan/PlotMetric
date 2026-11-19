import 'dart:io';

import '../../../core/utils/native_platform_helper.dart';
import '../ocr_models.dart';
import '../ocr_provider.dart';

List<OcrWord> _wordsFromMaps(List<Object?> raw) => [
  for (final value in raw)
    if (value is Map)
      OcrWord(
        text: value['text'] as String,
        x: (value['x'] as num).toDouble(),
        y: (value['y'] as num).toDouble(),
        height: (value['height'] as num).toDouble(),
        width: (value['width'] as num?)?.toDouble(),
      ),
];

/// Google ML Kit text recognition, running in the existing Android native code (offline).
class GoogleMlKitProvider extends OcrProvider {
  const GoogleMlKitProvider();

  @override
  String get id => 'google_mlkit';
  @override
  String get name => 'Google ML Kit';
  @override
  String get version => 'text-recognition 16.0.1 (Latin, bundled model)';
  @override
  Set<String> get platforms => const {'android'};
  @override
  bool get online => false;

  @override
  Future<OcrAvailability> availability() async => Platform.isAndroid
      ? const OcrAvailability.ready('Offline, built into the app')
      : const OcrAvailability.unsupported('Android only');

  @override
  Future<OcrRun> recognize(String imagePath, {OcrCancelToken? cancel}) =>
      runTimed(this, () async {
        final raw = await NativePlatformHelper.recognizeImageTable(imagePath);
        return (
          words: _wordsFromMaps(raw),
          rawText: raw.map((word) => (word as Map)['text']).join(' '),
          warnings: const [
            'ML Kit reports no per-word confidence in this integration.',
          ],
        );
      }, cancel: cancel);
}

/// The Windows built-in OCR engine (Windows.Media.Ocr), read several ways and merged. Offline.
class WindowsNativeProvider extends OcrProvider {
  WindowsNativeProvider();

  OcrAvailability? _cached;

  @override
  String get id => 'windows_native';
  @override
  String get name => 'Windows Native OCR';
  @override
  String get version => 'Windows.Media.Ocr (multi-pass)';
  @override
  Set<String> get platforms => const {'windows'};
  @override
  bool get online => false;

  @override
  Future<OcrAvailability> availability() async {
    if (!Platform.isWindows) {
      return const OcrAvailability.unsupported('Windows only');
    }
    if (_cached != null) {
      return _cached!;
    }
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'''
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
[Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages.Count
''',
      ]);
      final count = int.tryParse(result.stdout.toString().trim()) ?? 0;
      return _cached = count > 0
          ? const OcrAvailability.ready('Offline, built into Windows')
          : const OcrAvailability.setupRequired(
              'No Windows OCR language is installed. Add one under Settings > Time & language > Language.',
            );
    } catch (error) {
      return OcrAvailability.setupRequired(
        'Could not query Windows OCR: $error',
      );
    }
  }

  @override
  Future<OcrRun> recognize(String imagePath, {OcrCancelToken? cancel}) =>
      runTimed(this, () async {
        final raw = await NativePlatformHelper.recognizeImageTable(imagePath);
        return (
          words: _wordsFromMaps(raw),
          rawText: raw.map((word) => (word as Map)['text']).join(' '),
          warnings: const ['Windows OCR reports no per-word confidence.'],
        );
      }, cancel: cancel);
}
