import 'ocr_models.dart';

/// One independent OCR engine. Providers do not share code paths for recognition, and a
/// provider must never present another engine's output as its own.
abstract class OcrProvider {
  const OcrProvider();

  /// Stable identifier stored with saved results (for example `windows_native`).
  String get id;
  String get name;

  /// Engine or library version, as far as it can be known without running it.
  String get version;

  /// Platforms the engine can run on: `android`, `windows`.
  Set<String> get platforms;

  /// True when the picture leaves the device.
  bool get online;

  /// Whether the engine can run here, and if not, why. Never throws.
  Future<OcrAvailability> availability();

  /// Reads [imagePath] and returns every word with its position. Throws only on programmer
  /// error; recoverable problems are reported in [OcrRun.error] / [OcrRun.warnings].
  Future<OcrRun> recognize(String imagePath, {OcrCancelToken? cancel});
}

/// Times [body], converts failures into a failed [OcrRun], and honours cancellation.
Future<OcrRun> runTimed(
  OcrProvider provider,
  Future<({List<OcrWord> words, String rawText, List<String> warnings})>
  Function()
  body, {
  OcrCancelToken? cancel,
}) async {
  final clock = Stopwatch()..start();
  try {
    if (cancel?.isCancelled ?? false) throw const OcrCancelled();
    final result = await body();
    if (cancel?.isCancelled ?? false) throw const OcrCancelled();
    return OcrRun(
      engineId: provider.id,
      engineName: provider.name,
      engineVersion: provider.version,
      online: provider.online,
      words: result.words,
      rawText: result.rawText,
      duration: clock.elapsed,
      warnings: result.warnings,
    );
  } on OcrCancelled {
    rethrow;
  } catch (error) {
    return OcrRun(
      engineId: provider.id,
      engineName: provider.name,
      engineVersion: provider.version,
      online: provider.online,
      words: const [],
      rawText: '',
      duration: clock.elapsed,
      error: error
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('StateError: ', ''),
    );
  }
}
