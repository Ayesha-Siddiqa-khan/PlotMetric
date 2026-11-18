enum EntryOperation {
  add('ADD'),
  subtract('SUBTRACT');

  final String dbValue;
  const EntryOperation(this.dbValue);

  static EntryOperation fromDb(String value) {
    return value == 'SUBTRACT' ? EntryOperation.subtract : EntryOperation.add;
  }
}

class MeasurementEntry {
  final int? id;
  final int? calculationId;
  final int sortOrder;
  final String purpose;
  final EntryOperation operation;
  final int kanal;
  final int marla;
  final int sarsaiCenti;

  const MeasurementEntry({
    this.id,
    this.calculationId,
    required this.sortOrder,
    required this.purpose,
    required this.operation,
    required this.kanal,
    required this.marla,
    required this.sarsaiCenti,
  });

  bool get isSubtract => operation == EntryOperation.subtract;

  MeasurementEntry copyWith({
    int? id,
    int? calculationId,
    int? sortOrder,
    String? purpose,
    EntryOperation? operation,
    int? kanal,
    int? marla,
    int? sarsaiCenti,
  }) {
    return MeasurementEntry(
      id: id ?? this.id,
      calculationId: calculationId ?? this.calculationId,
      sortOrder: sortOrder ?? this.sortOrder,
      purpose: purpose ?? this.purpose,
      operation: operation ?? this.operation,
      kanal: kanal ?? this.kanal,
      marla: marla ?? this.marla,
      sarsaiCenti: sarsaiCenti ?? this.sarsaiCenti,
    );
  }

  Map<String, dynamic> toMap({int? overrideCalculationId}) {
    final map = <String, dynamic>{
      'sort_order': sortOrder,
      'purpose': purpose.trim().isEmpty ? 'Nil' : purpose.trim(),
      'operation': operation.dbValue,
      'kanal': kanal,
      'marla': marla,
      'sarsai_centi': sarsaiCenti,
    };
    if (id != null) map['id'] = id;
    final cId = overrideCalculationId ?? calculationId;
    if (cId != null) map['calculation_id'] = cId;
    return map;
  }

  factory MeasurementEntry.fromMap(Map<String, dynamic> map) {
    return MeasurementEntry(
      id: map['id'] as int?,
      calculationId: map['calculation_id'] as int?,
      sortOrder: map['sort_order'] as int,
      purpose: map['purpose'] as String? ?? 'Nil',
      operation: EntryOperation.fromDb(map['operation'] as String? ?? 'ADD'),
      kanal: map['kanal'] as int? ?? 0,
      marla: map['marla'] as int? ?? 0,
      sarsaiCenti: map['sarsai_centi'] as int? ?? 0,
    );
  }
}
