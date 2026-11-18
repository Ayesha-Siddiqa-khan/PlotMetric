# PlotMetric (v1.1)

PlotMetric is an offline, privacy-first cross-platform application for land measurement and deduction workflows, housing scheme planning, architectural plot dimension conversions, and everyday arithmetic calculations.

Built with **Flutter (Dart null-safety)**, **Material 3**, **Riverpod**, and **SQLite**.

---

## Key Modules & Capabilities

### 1. Land Measurement & Colony Deduction Engine
- **Single Continuous Sheet**: Responsive tabular data entry with clean dividers, gross running balances, and real-time total net balances.
- **Pure Integer Arithmetic**: Exact calculations in **centi-Sarsai** (hundredths of a Sarsai) eliminating floating-point drift.
- **Regional Revenue Standard**:
  - `1 Karam = 5.5 Feet (66 Inches)`
  - `1 Sarsai = 1 Karam × 1 Karam = 30.25 sq ft`
  - `1 Marla = 9 Sarsai = 272.25 sq ft`
  - `1 Kanal = 20 Marla = 180 Sarsai = 5,445 sq ft`
  - `1 Acre / Qila = 8 Kanal = 160 Marla = 43,560 sq ft`
  - `1 Murabba = 25 Acres = 200 Kanal = 1,089,000 sq ft`
- **Dashed Land Notation**: Uniform dashed notation throughout the UI, exports, and shares (e.g. `95 Kanal - 10 Marla - 0 Sarsai` and `95K - 10M - 0S`).
- **Click-to-Clear Inputs**: True placeholders (`hintText: 'Nil'`, `hintText: '0'`). Clicking any input automatically clears default values or selects all, avoiding manual backspacing.
- **Housing Scheme Presets**: Instant colony deduction template generator (Roads, Parks, Mosque, Graveyard, Sewerage, Commercial, etc.).

### 2. Plot Dimensions & Site Plan Converter
- **Length × Width Mode**: Enter blueprint dimensions in Feet and Inches with instant conversion to Kanal, Marla, and Sarsai.
- **Direct Sq Ft Mode**: Instantly convert any square footage into standard revenue units with quick presets (1 Sarsai to 1 Acre).
- **Dashed Blueprint Formatting**: Automatically formats plot measurements as `Plot (10' - 5" × 70' - 0")`.
- **Optional Square Yards (گز) Checkbox**: Unchecked by default for clean land sheets; check to include Square Yards in worksheet descriptions and reports.
- **Autofocus & New Plot Reset**: Focus defaults directly on Plot Width, with a 1-tap "New / Clear" reset button.

### 3. Multi-Format Export, Print & Sharing
- **Black & White A4 PDF**: Clean, print-ready document formatted with tabular breakdowns, custom editable subtitles, and date/units notes.
- **Open / Print**: Direct 1-tap PDF viewing and native system printing.
- **Word (.doc)**: Formatted HTML-based Word document with styled tables and summary boxes.
- **Excel Spreadsheet (.csv)**: Clean CSV export with proper numerical column types.
- **WhatsApp Direct Share**: Formatted Markdown breakdown ready to copy or send directly.
- Available across **Land Calculator**, **Dimensions**, **Records**, and **Document Scanner**.

### 4. OCR & Mutation Document Scanner
- **On-Device Parsing**: Extract Kanal, Marla, Sarsai, and amenity descriptions from pasted deeds or housing scheme blueprints.
- **Editable Table**: Inspect and adjust values, toggle `+` / `−` operations, or remove rows.
- **Direct Actions**: Transfer directly to Land Calculator or export immediately to PDF/Word/CSV.

### 5. Land Units & Revenue Standards Guide
- Complete interactive guide covering revenue vs. private society measurements (272.25 vs 225 sq ft).
- Live bidirectional unit converter between Sarsai, Marla, Kanal, Acre, Murabba, Sq Ft, and Sq Yards.
- Standard Pakistani residential plot dimension reference table (3 Marla to 2 Kanal).

### 6. Settings & Data Management
- **JSON Backup & Restore**: Create full offline JSON backups and restore saved calculations.
- **Bulk Export**: Export the entire SQLite database to PDF, Word, or CSV in one click.
- **Data Protection**: Secure local storage with cascade deletes and safe reset confirmation.

---

## App Branding & Icons
- Configured across Android (adaptive, monochrome, and mipmap densities), Windows `.ico`, iOS AppIcon set, Web favicons, and Google Play Store 512×512 asset.

---

## Quality & Verification
- **Automated Git Hooks**: Pre-push hook automatically enforces `flutter test --no-pub` before every remote push.
- **100% Test Coverage**: Comprehensive unit and widget tests covering integer math, formatters, exporters, and responsive layouts.
