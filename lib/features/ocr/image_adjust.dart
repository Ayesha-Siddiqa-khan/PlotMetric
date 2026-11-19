import 'dart:typed_data';

/// Pixel adjustments applied once to the confirmed crop, so every OCR engine receives identical input.
class ImageAdjustments {
  const ImageAdjustments({
    this.brightness = 0,
    this.contrast = 1,
    this.grayscale = false,
    this.sharpen = false,
  });

  /// -0.5 .. 0.5 (fraction of the full brightness range).
  final double brightness;

  /// 0.5 .. 2.0 around mid grey.
  final double contrast;
  final bool grayscale, sharpen;

  bool get isDefault =>
      brightness == 0 && contrast == 1 && !grayscale && !sharpen;
  bool get needsColorFilter => brightness != 0 || contrast != 1 || grayscale;

  Map<String, Object> toJson() => {
    'brightness': brightness,
    'contrast': contrast,
    'grayscale': grayscale,
    'sharpen': sharpen,
  };

  /// A 4x5 colour matrix (Flutter ColorFilter.matrix layout) for brightness, contrast and grayscale.
  List<double> colorMatrix() {
    final offset = 128 * (1 - contrast) + brightness * 255;
    List<double> row(int channel) {
      final weights = grayscale
          ? const [0.2126, 0.7152, 0.0722]
          : [for (var i = 0; i < 3; i++) i == channel ? 1.0 : 0.0];
      return [for (final weight in weights) weight * contrast, 0, offset];
    }

    return [...row(0), ...row(1), ...row(2), 0, 0, 0, 1, 0];
  }
}

/// Unsharp-style 3x3 sharpening of RGBA pixels (alpha is left alone). Edges are copied unchanged.
Uint8List sharpenRgba(
  Uint8List rgba,
  int width,
  int height, {
  double amount = 0.8,
}) {
  final out = Uint8List.fromList(rgba);
  if (width < 3 || height < 3) return out;
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final i = (y * width + x) * 4;
      for (var c = 0; c < 3; c++) {
        final neighbours =
            rgba[i - 4 + c] +
            rgba[i + 4 + c] +
            rgba[i - width * 4 + c] +
            rgba[i + width * 4 + c];
        final value = rgba[i + c] + amount * (4 * rgba[i + c] - neighbours);
        out[i + c] = value.round().clamp(0, 255);
      }
    }
  }
  return out;
}
