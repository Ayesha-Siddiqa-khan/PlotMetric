import '../../export/logic/table_formats.dart';
import 'approved_land.dart';

/// The register columns a person can include in an export.
enum ApprovedLandColumn {
  serial('Sr.No.', 0.5, centred: true),
  name('Name of Housing Scheme', 2.2),
  owner('Name of Owners / Developers', 2.8),
  mouza('Name of Mouza (s) / Address / Road', 2.0),
  totalArea('Total Area (K-M-S)', 1.5, centred: true),
  transferTotal('Total Transferable Area to MC (K-M-S)', 1.7, centred: true),
  transferred('Transferred to MC (K-M-S)', 1.5, centred: true),
  remaining('Remaining Transfer (K-M-S)', 1.5, centred: true),
  mortgage('Mortgage Deed (K-M-S)', 1.4, centred: true),
  note('Note', 2.0);

  const ApprovedLandColumn(this.label, this.weight, {this.centred = false});

  final String label;
  final double weight;
  final bool centred;

  bool get isArea =>
      index >= ApprovedLandColumn.totalArea.index &&
      index <= ApprovedLandColumn.mortgage.index;

  /// What an export shows for this cell. Areas are always K-M-S; an empty area shows a dash.
  String valueOf(ApprovedLandEntry entry) {
    final text = switch (this) {
      serial => entry.serial?.toString() ?? '',
      name => entry.name,
      owner => entry.owner,
      mouza => entry.mouza,
      totalArea => LandAreaText.normalize(entry.totalArea),
      transferTotal => LandAreaText.normalize(entry.transferTotal),
      transferred => LandAreaText.normalize(entry.transferred),
      remaining => LandAreaText.normalize(entry.remaining),
      mortgage => LandAreaText.normalize(entry.mortgage),
      note => entry.note,
    };
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty && (isArea || this == serial) ? '-' : cleaned;
  }
}

class ApprovedLandExport {
  const ApprovedLandExport._();

  static const title = 'Detail of Approved Land Sub-Division';
  static const subtitle = 'Municipal Committee Chishtian';

  static List<ExportColumn> get columns => [
    for (final column in ApprovedLandColumn.values)
      ExportColumn(
        column.name,
        column.label,
        weight: column.weight,
        centred: column.centred,
      ),
  ];

  /// One group holding the chosen colonies; every register column is present so the dialog can pick.
  static ExportGroup group(List<ApprovedLandEntry> entries) => ExportGroup(
    'Approved Land',
    [
      for (final entry in entries)
        [for (final column in ApprovedLandColumn.values) column.valueOf(entry)],
    ],
  );
}
