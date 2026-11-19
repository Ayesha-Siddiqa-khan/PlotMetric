import 'ocr_models.dart';

/// Reads the word boxes out of Tesseract's hOCR output. Pure Dart, so it is tested without a device.
List<OcrWord> parseHocr(String hocr) {
  final words = <OcrWord>[];
  final tag = RegExp(
    r'''<span\b([^>]*\bclass\s*=\s*['"]ocrx_word['"][^>]*)>(.*?)</span>''',
    dotAll: true,
  );
  for (final match in tag.allMatches(hocr)) {
    final attributes = match.group(1)!;
    final title = RegExp(
      r'''title\s*=\s*['"]([^'"]*)['"]''',
    ).firstMatch(attributes)?.group(1);
    final box = title == null
        ? null
        : RegExp(
            r'bbox\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)',
          ).firstMatch(title);
    if (box == null) continue;
    final text = _decode(
      match.group(2)!.replaceAll(RegExp(r'<[^>]*>'), ''),
    ).trim();
    if (text.isEmpty) continue;
    final left = double.parse(box.group(1)!), top = double.parse(box.group(2)!);
    final right = double.parse(box.group(3)!),
        bottom = double.parse(box.group(4)!);
    final confidence = double.tryParse(
      RegExp(r'x_wconf\s+(\d+(?:\.\d+)?)').firstMatch(title!)?.group(1) ?? '',
    );
    words.add(
      OcrWord(
        text: text,
        x: (left + right) / 2,
        y: (top + bottom) / 2,
        height: bottom - top,
        width: right - left,
        confidence: confidence == null
            ? null
            : (confidence / 100).clamp(0.0, 1.0),
      ),
    );
  }
  return words;
}

String _decode(String text) => text
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'");
