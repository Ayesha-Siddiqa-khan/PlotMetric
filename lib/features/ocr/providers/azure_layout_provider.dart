import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../ocr_models.dart';
import '../ocr_provider.dart';
import '../ocr_settings.dart';

/// Azure AI Document Intelligence `prebuilt-layout`, reached through YOUR backend proxy. Online.
///
/// No Azure key is stored in the app. The proxy holds the key, receives
/// `POST <proxy>` with `{"contentType": "image/png", "image": "<base64>"}` and returns the
/// Azure `analyzeResult` JSON (or `{"analyzeResult": {...}}`). The picture is only sent after
/// [grantConsent] was called for that exact file, which the Scan page does after showing the
/// user the crop and asking.
class AzureLayoutProvider extends OcrProvider {
  AzureLayoutProvider({this.settings, this.client});

  final OcrSettings? settings;
  final http.Client? client;
  final _consented = <String>{};

  @override
  String get id => 'azure_layout';
  @override
  String get name => 'Azure Document Intelligence';
  @override
  String get version => 'prebuilt-layout (via your proxy)';
  @override
  Set<String> get platforms => const {'android', 'windows'};
  @override
  bool get online => true;

  void grantConsent(String imagePath) => _consented.add(imagePath);
  void revokeConsent(String imagePath) => _consented.remove(imagePath);

  Future<String?> _proxyUrl() =>
      (settings ?? OcrSettings()).read(OcrSettings.azureProxyKey);

  @override
  Future<OcrAvailability> availability() async {
    if (!Platform.isAndroid && !Platform.isWindows) {
      return const OcrAvailability.unsupported('Android and Windows only');
    }
    final url = await _proxyUrl();
    if (url == null || Uri.tryParse(url)?.hasAuthority != true) {
      return const OcrAvailability.setupRequired(
        'Set the backend proxy address in OCR settings. Online engine: the crop is uploaded only after you agree.',
      );
    }
    return const OcrAvailability.ready(
      'Online. Needs internet and your consent for each upload',
    );
  }

  @override
  Future<OcrRun> recognize(
    String imagePath, {
    OcrCancelToken? cancel,
  }) => runTimed(this, () async {
    if (!_consented.contains(imagePath)) {
      throw StateError(
        'Upload not allowed: the user has not agreed to send this crop online.',
      );
    }
    final url = await _proxyUrl();
    if (url == null) throw StateError('No backend proxy address is set.');
    final http_ = client ?? http.Client();
    try {
      final bytes = await File(imagePath).readAsBytes();
      final response = await http_
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contentType': 'image/png',
              'image': base64Encode(bytes),
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 429) {
        final wait = response.headers['retry-after'];
        throw StateError(
          'The service is rate limiting requests${wait == null ? '' : '; try again in $wait seconds'}.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError(
          'The proxy refused the request (${response.statusCode}). Check its credentials and quota.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('The proxy answered ${response.statusCode}.');
      }
      final words = parseAzureLayout(response.body);
      return (
        words: words,
        rawText: response.body,
        warnings: const ['Online engine: usage may be billed by Azure.'],
      );
    } on TimeoutException {
      throw StateError('The service did not answer within 60 seconds.');
    } on SocketException {
      throw StateError('No internet connection.');
    } finally {
      if (client == null) http_.close();
      _consented.remove(imagePath);
    }
  }, cancel: cancel);
}

/// Words with boxes and confidence from an Azure Document Intelligence `analyzeResult`.
List<OcrWord> parseAzureLayout(String body) {
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  final result = (decoded['analyzeResult'] ?? decoded) as Map<String, dynamic>;
  final words = <OcrWord>[];
  for (final page in (result['pages'] as List? ?? [])) {
    for (final word in ((page as Map)['words'] as List? ?? [])) {
      final map = word as Map;
      final polygon = (map['polygon'] as List? ?? [])
          .map((v) => (v as num).toDouble())
          .toList();
      if (polygon.length < 8) continue;
      final xs = [for (var i = 0; i < polygon.length; i += 2) polygon[i]];
      final ys = [for (var i = 1; i < polygon.length; i += 2) polygon[i]];
      final left = xs.reduce((a, b) => a < b ? a : b),
          right = xs.reduce((a, b) => a > b ? a : b);
      final top = ys.reduce((a, b) => a < b ? a : b),
          bottom = ys.reduce((a, b) => a > b ? a : b);
      words.add(
        OcrWord(
          text: map['content'] as String,
          x: (left + right) / 2,
          y: (top + bottom) / 2,
          height: bottom - top,
          width: right - left,
          confidence: (map['confidence'] as num?)?.toDouble(),
        ),
      );
    }
  }
  return words;
}
