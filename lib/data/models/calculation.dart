import 'measurement_entry.dart';
import '../../features/land/logic/land_math.dart';

class Calculation {
  final int? id;
  final String title;
  final String calculationDate; // ISO yyyy-MM-dd
  final String calculationTime; // HH:mm
  final String createdAtUtc;
  final String updatedAtUtc;
  final List<MeasurementEntry> entries;

  const Calculation({
    this.id,
    required this.title,
    required this.calculationDate,
    required this.calculationTime,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.entries = const [],
  });

  Calculation copyWith({
    int? id,
    String? title,
    String? calculationDate,
    String? calculationTime,
    String? createdAtUtc,
    String? updatedAtUtc,
    List<MeasurementEntry>? entries,
  }) {
    return Calculation(
      id: id ?? this.id,
      title: title ?? this.title,
      calculationDate: calculationDate ?? this.calculationDate,
      calculationTime: calculationTime ?? this.calculationTime,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title.trim(),
      'calculation_date': calculationDate,
      'calculation_time': calculationTime,
      'created_at_utc': createdAtUtc,
      'updated_at_utc': updatedAtUtc,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Calculation.fromMap(Map<String, dynamic> map, {List<MeasurementEntry> entries = const []}) {
    return Calculation(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      calculationDate: map['calculation_date'] as String? ?? '',
      calculationTime: map['calculation_time'] as String? ?? '',
      createdAtUtc: map['created_at_utc'] as String? ?? '',
      updatedAtUtc: map['updated_at_utc'] as String? ?? '',
      entries: entries,
    );
  }

  /// Calculates summary from entries
  LandWorksheetSummary get summary {
    final rows = entries.map((e) {
      final centi = LandMath.rowToCentiSarsai(
        kanal: e.kanal,
        marla: e.marla,
        sarsaiCenti: e.sarsaiCenti,
      );
      return (isSubtract: e.isSubtract, centiSarsai: centi);
    }).toList();
    return LandMath.computeSummary(rows);
  }
}
