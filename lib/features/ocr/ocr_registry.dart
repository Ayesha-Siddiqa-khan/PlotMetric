import 'dart:io';

import 'ocr_models.dart';
import 'ocr_provider.dart';
import 'ocr_settings.dart';
import 'providers/azure_layout_provider.dart';
import 'providers/native_table_provider.dart';
import 'providers/paddle_not_installed_provider.dart';
import 'providers/tesseract_provider.dart';

/// An engine plus what it can do right now on this device.
class OcrEngineStatus {
  const OcrEngineStatus(this.provider, this.availability);
  final OcrProvider provider;
  final OcrAvailability availability;
}

/// The engines offered on this platform. Only providers that belong to the running platform
/// are created, so no other platform's native code is touched.
class OcrRegistry {
  // ignore: prefer_initializing_formals
  OcrRegistry(this.providers, {OcrSettings? settings}) : _settings = settings;

  /// Providers for the platform the app is running on.
  factory OcrRegistry.forThisPlatform({OcrSettings? settings}) => OcrRegistry([
    // Unit and widget tests never touch real engines.
    if (!Platform.environment.containsKey('FLUTTER_TEST')) ...[
      if (Platform.isAndroid) ...const [
        GoogleMlKitProvider(),
        TesseractProvider(),
        PaddleNotInstalledProvider(),
      ],
      if (Platform.isWindows) ...[
        WindowsNativeProvider(),
        const PaddleNotInstalledProvider(),
      ],
      if (Platform.isAndroid || Platform.isWindows)
        AzureLayoutProvider(settings: settings),
    ],
  ], settings: settings);

  final List<OcrProvider> providers;
  final OcrSettings? _settings;
  OcrSettings get settings => _settings ?? OcrSettings();

  OcrProvider? byId(String id) =>
      providers.where((provider) => provider.id == id).firstOrNull;

  Future<List<OcrEngineStatus>> statuses() async => [
    for (final provider in providers)
      OcrEngineStatus(provider, await provider.availability()),
  ];

  /// The saved choice if it is still usable, otherwise the first ready offline engine.
  Future<OcrProvider?> preferred() async {
    if (providers.isEmpty) {
      return null;
    }
    final all = await statuses();
    final saved = await settings.preferredEngine();
    for (final status in all) {
      if (status.provider.id == saved && status.availability.isReady) {
        return status.provider;
      }
    }
    return all
        .where((s) => s.availability.isReady && !s.provider.online)
        .firstOrNull
        ?.provider;
  }

  /// Runs every ready offline engine over the same crop, one after another.
  /// Online engines are never included. Results keep the order of [providers].
  Stream<OcrRun> runAllOffline(
    String imagePath, {
    OcrCancelToken? cancel,
  }) async* {
    for (final status in await statuses()) {
      if (cancel?.isCancelled ?? false) {
        return;
      }
      if (!status.availability.isReady || status.provider.online) continue;
      try {
        yield await status.provider.recognize(imagePath, cancel: cancel);
      } on OcrCancelled {
        return;
      }
    }
  }
}
