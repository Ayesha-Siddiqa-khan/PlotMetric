import '../../land/logic/land_math.dart';
import '../../schemes/logic/scheme.dart';

/// Area text helpers for the approved-land register. Every area is shown as
/// Kanal-Marla-Sarsai ("91K-16M-0S"). Text that cannot be read as an area is
/// kept exactly as typed so nothing printed on the source sheet is lost.
class LandAreaText {
  const LandAreaText._();

  static final _token = RegExp(r'(\d+(?:\.\d+)?)\s*([KMSkms])');

  /// Area in ten-thousandths of a sq ft, or null when the text is not a valid area.
  static int? parse(String text) {
    final value = text.trim();
    if (value.isEmpty || value == '-' || value == '—') return null;
    final matches = _token.allMatches(value).toList();
    if (matches.isEmpty) return null;
    // Only separators may sit between the parts.
    final leftover = value.replaceAll(_token, '').replaceAll(RegExp(r'[\s,\-/.]+'), '');
    if (leftover.isNotEmpty) return null;
    final parts = <String, String>{};
    for (final match in matches) {
      final unit = match.group(2)!.toUpperCase();
      if (parts.containsKey(unit)) return null;
      parts[unit] = match.group(1)!;
    }
    return SchemeArea.land(parts['K'] ?? '0', parts['M'] ?? '0', parts['S'] ?? '0');
  }

  /// Canonical "K-M-S" text for a stored area (negative values get a leading minus).
  static String format(int? area) {
    if (area == null) return '';
    final units = (area.abs() + SchemeArea.unit ~/ 2) ~/ SchemeArea.unit;
    final c = LandMath.centiSarsaiToComposite(units);
    final sign = area < 0 ? '-' : '';
    return '$sign${c.kanal}K-${c.marla}M-${c.sarsaiFormatted}S';
  }

  /// Canonical text when the input is a valid area. Text made of K/M/S parts that is not a
  /// valid area (for example 35 Marla) keeps its numbers but gets the same dashes. Anything else is kept as typed.
  static String normalize(String text) {
    final value = text.trim();
    final area = parse(value);
    if (area != null) return format(area);
    final matches = _token.allMatches(value).toList();
    final leftover = value.replaceAll(_token, '').replaceAll(RegExp(r'[\s,\-/.]+'), '');
    if (matches.isEmpty || leftover.isNotEmpty) return value;
    return matches.map((m) => '${m.group(1)}${m.group(2)!.toUpperCase()}').join('-');
  }
}

class ApprovedLandEntry {
  ApprovedLandEntry({
    this.id,
    this.serial,
    this.name = '',
    this.owner = '',
    this.mouza = '',
    this.totalArea = '',
    this.transferTotal = '',
    this.transferred = '',
    this.remaining = '',
    this.mortgage = '',
    this.note = '',
    this.schemeId,
  });

  int? id;
  int? serial;
  String name, owner, mouza;
  String totalArea, transferTotal, transferred, remaining, mortgage;
  String note;

  /// The saved scan (housing_schemes row) that produced the transfer figures.
  int? schemeId;

  /// Remaining = total transfer area less what is already transferred, when both are valid areas.
  static String computeRemaining(String transferTotal, String transferred) {
    final total = LandAreaText.parse(transferTotal);
    if (total == null) return '';
    final done = transferred.trim().isEmpty ? 0 : LandAreaText.parse(transferred);
    return done == null ? '' : LandAreaText.format(total - done);
  }

  ApprovedLandEntry copy() => ApprovedLandEntry(
    id: id,
    serial: serial,
    name: name,
    owner: owner,
    mouza: mouza,
    totalArea: totalArea,
    transferTotal: transferTotal,
    transferred: transferred,
    remaining: remaining,
    mortgage: mortgage,
    note: note,
    schemeId: schemeId,
  );

  Map<String, Object?> toDb() => {
    if (id != null) 'id': id,
    'serial': serial,
    'name': name.trim(),
    'owner': owner.trim(),
    'mouza': mouza.trim(),
    'total_area': totalArea.trim(),
    'transfer_total': transferTotal.trim(),
    'transferred': transferred.trim(),
    'remaining': remaining.trim(),
    'mortgage': mortgage.trim(),
    'note': note.trim(),
    'scheme_id': schemeId,
  };

  factory ApprovedLandEntry.fromDb(Map<String, Object?> row) => ApprovedLandEntry(
    id: row['id'] as int?,
    serial: row['serial'] as int?,
    name: row['name'] as String? ?? '',
    owner: row['owner'] as String? ?? '',
    mouza: row['mouza'] as String? ?? '',
    totalArea: row['total_area'] as String? ?? '',
    transferTotal: row['transfer_total'] as String? ?? '',
    transferred: row['transferred'] as String? ?? '',
    remaining: row['remaining'] as String? ?? '',
    mortgage: row['mortgage'] as String? ?? '',
    note: row['note'] as String? ?? '',
    schemeId: row['scheme_id'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'serial': serial,
    'name': name,
    'owner': owner,
    'mouza': mouza,
    'total_area': totalArea,
    'transfer_total': transferTotal,
    'transferred': transferred,
    'remaining': remaining,
    'mortgage': mortgage,
    'note': note,
  };

  factory ApprovedLandEntry.fromJson(Map<String, dynamic> map) => ApprovedLandEntry(
    serial: (map['serial'] as num?)?.toInt(),
    name: map['name'] as String? ?? '',
    owner: map['owner'] as String? ?? '',
    mouza: map['mouza'] as String? ?? '',
    totalArea: map['total_area'] as String? ?? '',
    transferTotal: map['transfer_total'] as String? ?? '',
    transferred: map['transferred'] as String? ?? '',
    remaining: map['remaining'] as String? ?? '',
    mortgage: map['mortgage'] as String? ?? '',
    note: map['note'] as String? ?? '',
  );
}
