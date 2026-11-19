import 'dart:io';

import '../ocr_models.dart';
import '../ocr_provider.dart';

/// Stands in for PaddleOCR so people can see why it is off. The PaddleOCR plugins are not part of
/// this build: `paddle_ocr_native` needs Android API 26 and arm64 only (this app supports API 24),
/// and `pp_ocr` needs OpenCV (OpenCV_DIR) plus separately supplied model files on Windows.
/// See docs/ocr/compatibility_report.md for how to enable either one.
class PaddleNotInstalledProvider extends OcrProvider {
  const PaddleNotInstalledProvider();

  @override
  String get id => 'paddle';
  @override
  String get name => 'PaddleOCR';
  @override
  String get version => 'not installed in this build';
  @override
  Set<String> get platforms => const {'android', 'windows'};
  @override
  bool get online => false;

  @override
  Future<OcrAvailability> availability() async => OcrAvailability.unsupported(
    Platform.isAndroid
        ? 'Disabled: the Android plugin needs API 26 and arm64 only, and this app supports API 24. See the compatibility report.'
        : 'Disabled: the Windows plugin needs OpenCV and model files that are not set up. See the compatibility report.',
  );

  @override
  Future<OcrRun> recognize(String imagePath, {OcrCancelToken? cancel}) =>
      runTimed(this, () async {
        throw StateError('PaddleOCR is not installed in this build.');
      }, cancel: cancel);
}
