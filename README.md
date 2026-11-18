# PlotMetric (v1.0)

PlotMetric is an offline, privacy-first cross-platform application for land measurement and deduction workflows, housing scheme planning, and everyday arithmetic calculations.

Built with **Flutter (Dart null-safety)**, **Material 3**, **Riverpod**, and **SQLite**.

---

## Features

1. **Land Measurement & Deduction Engine**:
   - Single continuous measurement sheet with thin dividers (no bulky separate cards).
   - Fixed standard conversion profile:
     - `1 Kanal = 20 Marla = 180 Sarsai = 5,445 sq ft`
     - `1 Marla = 9 Sarsai = 272.25 sq ft`
     - `1 Sarsai = 30.25 sq ft`
   - Exact integer math in **centi-Sarsai** (hundredths of a Sarsai) to prevent floating-point drift.
   - Live square-foot calculations per row and composite totals (`Kanal`, `Marla`, `Sarsai`).
   - Searchable / custom Purpose descriptions (up to 60 characters), preloaded with historical SQLite terms.
   - Single-tap `+ Add` and `− Deduct` buttons with immediate focus navigation.

2. **Saved Records & Search**:
   - On-device local persistence via SQLite (`plotmetric.db`) with foreign-key cascade deletes.
   - **Real-time Search**: Search saved calculations by title case-insensitively with instant feedback.
   - Tap any record to reopen and edit the complete original worksheet.
   - Atomic updates (`Save Changes`) or duplicate copies (`Save as New`).

3. **Everyday Arithmetic Calculator**:
   - Standalone calculator with full operator precedence (multiplication/division evaluated before addition/subtraction).
   - Sign toggle (`±`), percentage conversion (`%`), and safe division-by-zero protection.
   - `Copy Result` button. State preserved during tab switching.

4. **OCR Scanner Placeholder**:
   - Honest `Coming Soon` status for future land mutation / deed image scanning with mandatory human verification. Zero camera/media permissions requested in v1.

5. **Responsive Multi-Platform Shell**:
   - **Mobile (< 720dp)**: Persistent 4-tab `BottomNavigationBar`, stacked compact measurement rows.
   - **Desktop & Web (≥ 720dp)**: Persistent `NavigationRail` sidebar, wide data grid alignment, and centered max-width layout.

---

## Project Structure

```text
lib/
├── core/
│   ├── constants/land_units.dart         # Conversion rates & bounds
│   ├── theme/app_theme.dart              # Navy (#182A43) & Teal (#117D72) M3 theme
│   └── utils/
│       ├── date_time_formatters.dart     # 12-hour (hh:mm a) & dd/MM/yy formatters
│       └── number_formatters.dart        # English comma grouping & exact decimal sq ft
├── data/
│   ├── local/app_database.dart           # SQLite database helper & schema
│   ├── models/
│   │   ├── calculation.dart              # Parent calculation entity
│   │   └── measurement_entry.dart        # Row item entity
│   └── repositories/
│       └── calculation_repository.dart   # Atomic SQLite CRUD & queries
├── features/
│   ├── calculator/
│   │   ├── logic/expression_evaluator.dart
│   │   └── presentation/calculator_screen.dart
│   ├── land/
│   │   ├── logic/land_math.dart          # Pure integer centi-Sarsai arithmetic
│   │   ├── state/
│   │   │   ├── land_controller.dart      # Riverpod worksheet state notifier
│   │   │   └── land_row_model.dart       # Row controller & focus nodes
│   │   └── presentation/
│   │       ├── land_screen.dart          # Main land calculation screen
│   │       └── widgets/
│   │           ├── land_summary.dart     # Net totals display
│   │           ├── measurement_row.dart  # Responsive table row widget
│   │           └── measurement_sheet.dart# Continuous sheet container
│   ├── records/
│   │   └── presentation/records_screen.dart # Searchable saved records screen
│   └── scan/
│       └── presentation/scan_placeholder_screen.dart # OCR preview placeholder
├── app.dart                              # Responsive Root Shell (Rail / BottomNav)
└── main.dart                             # Application entry point with ProviderScope
```

---

## Manual Windows PowerShell Commands

In accordance with project policy, all dependency updates and native builds are executed manually:

### 1. Build Android Universal Release APK
```powershell
# Working Directory: E:\github\PlotMetric
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### 2. Enable Windows Desktop Platform (Optional)
```powershell
# Working Directory: E:\github\PlotMetric
flutter create --platforms windows .
flutter pub add sqflite_common_ffi
flutter run -d windows
```

### 3. Graphify Architecture Analysis (Optional)
```powershell
# Working Directory: E:\github\PlotMetric
uv tool install graphify
graphify install
```
