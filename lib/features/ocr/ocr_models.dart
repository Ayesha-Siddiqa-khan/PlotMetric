/// Shared types for every OCR provider. A provider only reports what its engine actually
/// returned; nothing here fills in or guesses values.
library;

enum OcrStatus {
  /// Installed, configured and able to run on this device.
  ready,

  /// Supported on this platform but something is missing (a model, a language, a server address).
  setupRequired,

  /// Not available on this platform or device.
  unsupported,
}

class OcrAvailability {
  const OcrAvailability(this.status, this.reason);
  const OcrAvailability.ready([String reason = 'Ready'])
    : this(OcrStatus.ready, reason);
  const OcrAvailability.setupRequired(String reason)
    : this(OcrStatus.setupRequired, reason);
  const OcrAvailability.unsupported(String reason)
    : this(OcrStatus.unsupported, reason);

  final OcrStatus status;
  final String reason;
  bool get isReady => status == OcrStatus.ready;
}

/// One recognised word (or text fragment) with its position in the cropped image.
/// [x] and [y] are the centre of the box, in pixels of the image that was recognised.
class OcrWord {
  const OcrWord({
    required this.text,
    required this.x,
    required this.y,
    required this.height,
    this.width,
    this.confidence,
  });

  final String text;
  final double x, y, height;
  final double? width;

  /// 0..1 as reported by the engine, or null when the engine reports none.
  final double? confidence;

  Map<String, dynamic> toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'height': height,
    'width': ?width,
    'confidence': ?confidence,
  };

  factory OcrWord.fromJson(Map<String, dynamic> map) => OcrWord(
    text: map['text'] as String,
    x: (map['x'] as num).toDouble(),
    y: (map['y'] as num).toDouble(),
    height: (map['height'] as num).toDouble(),
    width: (map['width'] as num?)?.toDouble(),
    confidence: (map['confidence'] as num?)?.toDouble(),
  );
}

/// The complete, unmodified result of running one engine over one crop.
class OcrRun {
  const OcrRun({
    required this.engineId,
    required this.engineName,
    required this.engineVersion,
    required this.online,
    required this.words,
    required this.rawText,
    required this.duration,
    this.warnings = const [],
    this.error,
  });

  final String engineId, engineName, engineVersion;
  final bool online;
  final List<OcrWord> words;

  /// Whatever text the engine returned before any positions were attached (hOCR, plain text, JSON).
  final String rawText;
  final Duration duration;

  /// Recoverable problems (for example "this engine reports no confidence").
  final List<String> warnings;

  /// Set when the run failed; [words] is then empty.
  final String? error;

  bool get failed => error != null;

  Map<String, dynamic> toJson() => {
    'engineId': engineId,
    'engineName': engineName,
    'engineVersion': engineVersion,
    'online': online,
    'durationMs': duration.inMilliseconds,
    'warnings': warnings,
    'error': ?error,
    'words': [for (final word in words) word.toJson()],
  };

  factory OcrRun.fromJson(Map<String, dynamic> map) => OcrRun(
    engineId: map['engineId'] as String,
    engineName: map['engineName'] as String,
    engineVersion: map['engineVersion'] as String,
    online: map['online'] as bool? ?? false,
    words: [
      for (final word in map['words'] as List)
        OcrWord.fromJson((word as Map).cast<String, dynamic>()),
    ],
    rawText: '',
    duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
    warnings: (map['warnings'] as List? ?? []).cast<String>(),
    error: map['error'] as String?,
  );
}

class OcrCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class OcrCancelled implements Exception {
  const OcrCancelled();
  @override
  String toString() => 'Cancelled';
}
