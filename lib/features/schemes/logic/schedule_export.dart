import '../../export/logic/table_formats.dart';
import 'scheme.dart';

/// Columns for exporting a saved area schedule. Square feet and % are calculated from
/// Kanal/Marla/Sarsai (the scan never supplies them).
const scheduleExportColumns = [
  ExportColumn('serial', 'S.No', weight: 0.6, centred: true),
  ExportColumn('description', 'Description', weight: 3.2),
  ExportColumn('kanal', 'Kanal', weight: 0.9, centred: true),
  ExportColumn('marla', 'Marla', weight: 0.9, centred: true),
  ExportColumn('sarsai', 'Sarsai', weight: 0.9, centred: true),
  ExportColumn('sqft', 'Calculated Sq Ft', weight: 1.6, centred: true),
  ExportColumn('percent', '% of Total Area', weight: 1.2, centred: true),
  ExportColumn('use', 'Classification', weight: 1.8),
  ExportColumn('selected', 'Selected for transfer', weight: 1.3, centred: true),
];

/// The rows of one saved schedule, in the order of [scheduleExportColumns].
ExportGroup scheduleGroup(String name, List<SchemeRow> rows, Set<int> checked) {
  final total = rows
      .where((row) => row.classification == AreaClass.gross && (row.area ?? 0) > 0)
      .map((row) => row.area!)
      .firstOrNull;
  String text(String value) => value.trim().isEmpty ? '-' : value.trim();
  return ExportGroup(name, [
    for (final (index, row) in rows.indexed)
      [
        '${index + 1}',
        row.description.trim().isEmpty ? 'Unreadable description' : row.description.trim(),
        text(row.kanal),
        text(row.marla),
        text(row.sarsai),
        row.area == null ? '-' : SchemeArea.display(row.area).replaceAll(' sq ft', ''),
        row.percent.trim().isNotEmpty
            ? '${row.percent.trim()}%'
            : SchemeArea.percentDisplay(row.area, total).replaceAll('—', '-'),
        row.classification == AreaClass.review ? 'Needs review' : row.classification.label,
        checked.contains(row.id) ? 'Yes' : 'No',
      ],
  ]);
}
