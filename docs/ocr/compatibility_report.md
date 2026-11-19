# PlotMetric OCR — platform and compatibility report

Status words used below, and nothing else:

* **Tested** – run on a real target in this project and the result checked.
* **Built, not device-tested** – the code compiles and is unit-tested with recorded or fake data, but it has not been run on a physical device or emulator.
* **Blocked** – cannot be built or run until a decision or an installation is made.

## Engines

| Engine | Platform | Mode | Adapter | Status |
| --- | --- | --- | --- | --- |
| Windows Native OCR (`Windows.Media.Ocr`, several passes merged) | Windows | Offline | `providers/native_table_provider.dart` | **Tested** on Windows 11 with the supplied photographs (results below) |
| Google ML Kit text recognition 16.0.1 (bundled Latin model) | Android | Offline | `providers/native_table_provider.dart` (uses the existing Kotlin code) | **Built, not device-tested** in this session (no Android device or emulator was available). It was in use before this change and the Kotlin code is unchanged. |
| Tesseract 4 (LSTM), `eng.traineddata` | Android | Offline | `providers/tesseract_provider.dart` (asks the plugin for hOCR so word boxes exist) | **Built, not device-tested.** hOCR parsing is unit-tested. |
| PaddleOCR PP-OCRv6 | Android | Offline | none – shown as *Disabled* (`providers/paddle_not_installed_provider.dart`) | **Blocked** (see below) |
| PaddleOCR PP-OCRv6 | Windows | Offline | none – shown as *Disabled* | **Blocked** (see below) |
| Azure Document Intelligence `prebuilt-layout` | Android, Windows | Online, through your backend proxy | `providers/azure_layout_provider.dart` | **Built, not tested against Azure** (no backend exists yet). Consent gating, request shape, error handling and result parsing are unit-tested with a fake HTTP client. |

Tesseract is not offered on Windows: the `tesseract_ocr` plugin has no Windows implementation.

### Windows results through the new adapter (same crop, one engine)

| Image | Time | Rows recognised | K / M / S / sq ft cells correct | Notes |
| --- | --- | --- | --- | --- |
| 52 Kanal schedule (clean crop) | about 4.0 s | 6 of 7 | 28 of 28 | one description is not an exact match |
| 52 Kanal schedule (skewed photo) | about 3.3 s | 6 of 7 | 26 of 28 | Park & Green Belt K/M/S not read, left empty with a suggestion |
| 52 Kanal schedule (tilted copy) | about 4.6 s | 6 of 7 | 26 of 28 | same cells |
| 91 Kanal 16 Marla / Al-Khair style table | about 3.3 s | 5 of 5 | 14 of 14 | |
| Same table with a hole in the paper | about 4.8 s | 5 of 5 | 12 of 14 | the damaged road row is left for review |

"Cells correct" counts K, M, S and square feet against a table checked by hand. These are small samples, not a guarantee.

## Blocked: PaddleOCR

Both PaddleOCR packages were already in `pubspec.yaml` before this work. Building the app with them fails:

* **Android – `paddle_ocr_native` 0.1.1.** It declares `minSdk 26` and ships `arm64-v8a` only. PlotMetric's `minSdk` is 24, so Gradle stops with *"Manifest merger failed: uses-sdk:minSdkVersion 24 cannot be smaller than version 26"*. Raising `minSdk` would drop Android 7.x devices, and an ABI filter would drop 32-bit phones, so it was not done. The package also asks for Java 17 and Android SDK 36.
* **Windows – `pp_ocr` 0.5.5.** Its CMake step requires OpenCV (`OpenCV_DIR`), which is not installed, so *"Unable to generate build files"*. It also does not bundle models: `det.onnx`, `rec.onnx` and `dict.txt` must be supplied.

Decision recorded: keep `minSdk 24`, and remove both packages. This has been done (`flutter pub remove --offline paddle_ocr_native pp_ocr`).

The app code no longer imports either package. The engine list shows *PaddleOCR – Disabled* with the reason.

To enable one later, add the package, resolve its requirement, and write a provider under `lib/features/ocr/providers/` that returns `OcrWord`s (box centre, height, width, confidence) and register it in `ocr_registry.dart`:

* Android: set `minSdk` to 26, restrict packaging to `arm64-v8a` as the package README shows, then test on an arm64 phone.
* Windows: install OpenCV, set `OpenCV_DIR`, place the three model files in `%LOCALAPPDATA%\PlotMetric\ocr_models\paddle`.

## Build checks

| Target | Result |
| --- | --- |
| Windows debug build, repository as committed | **Fails** – `pp_ocr` needs OpenCV (above) |
| Android debug build (arm64), repository as committed | **Fails** – `paddle_ocr_native` minSdk 26 (above) |
| Windows debug build with `paddle_ocr_native` and `pp_ocr` removed (checked in a scratch copy, not your project) | **Builds** – `plotmetric.exe` produced |
| Android debug build (arm64) with both packages removed (scratch copy) | **Builds** – `app-debug.apk` produced, including the new `deviceInfo` Kotlin method. It needed `kotlin.incremental=false` on this machine (see below). |
| Release builds, 32-bit Android, other ABIs | not checked |
| `flutter analyze` | no issues |
| `flutter test` | 91 tests pass (they include the OCR adapters, registry, Azure consent, comparison and the database upgrade) |

The scratch copy re-resolved dependencies from the local cache, so its versions can differ slightly from your `pubspec.lock`. Run the two `flutter pub remove` commands in your own project and rebuild to confirm.

One more observation: on this machine the first Android build attempts failed inside Gradle with *"Could not close incremental caches"* for three plugin modules (`google_mlkit_commons`, `image_picker_android`, `paddle_ocr_native`). Setting `kotlin.incremental=false` in `android/gradle.properties` let compilation continue to the manifest error above. It is probably a local cache or drive problem (the pub cache is on C:, the project on E:), not a project defect, so the setting was **not** kept. If you see it, that setting is the workaround.

## What changed in the project

* New `lib/features/ocr/`: provider interface, registry, adapters, hOCR and Azure parsers, table reconstruction input, comparison and scoring, image adjustments, the selector panel and the compare screen.
* The existing table reconstruction (`SchemeScan.read`) is the single reconstruction engine for every provider. Region-level engines are split across their box width first.
* Database version 5 adds `app_settings` (preferred engine, optional Azure proxy address). Existing data is untouched.
* `MainActivity.kt` gains a read-only `deviceInfo` method (SDK level, CPU ABIs, app documents folder). The existing ML Kit method is unchanged.
* Crop screen: brightness, contrast, grayscale and sharpen; the original image path, crop rectangle, rotation and adjustments are kept.
* Saved schemes carry `ocr` provenance: engine and version, every engine's raw words, crop details and which engine each cell came from.

## Behaviour changes you should know about

* **OCR reads only the serial number, description, Kanal, Marla and Sarsai.** Square feet and the percentage are calculated by the app (Kanal x 20 x 272.25 and so on, in exact integer arithmetic; % = area / the Total Area row). The printed square-feet and % columns are not read into the table at all; they are only kept out of the Kanal/Marla/Sarsai columns. This replaces the earlier "scanned square feet versus K/M/S decision" idea, at your request.
* A cell that was not read stays empty and the row is marked *Needs review*; nothing is filled in from another column.
* A re-scan never replaces worksheet rows that recorded transfers refer to, and OCR never creates a Fard or Intiqal transfer.
* The square-feet box in the row editor is only a converter: typing a value fills Kanal/Marla/Sarsai and is not stored.

## Not done, by design or for lack of a target

* Perspective correction in the crop screen (the crop is a rectangle; rotate and straighten the photo first).
* No Azure backend is provided. The expected contract is in `providers/azure_layout_provider.dart`.
* Nothing was run on an Android device or emulator.
* Cancelling stops before the next engine starts; an engine that is already reading finishes first.
