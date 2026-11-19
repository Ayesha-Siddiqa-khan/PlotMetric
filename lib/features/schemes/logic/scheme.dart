import 'dart:convert';

import '../../../core/constants/land_units.dart';
import '../../../core/utils/number_formatters.dart';
import '../../land/logic/land_math.dart';

enum AreaClass {
  review('Needs review'),
  gross('Total scheme area'),
  plot('Owner plots'),
  transfer('Transferable'),
  other('Other non-plot'),
  subtotal('Excluded subtotal');

  const AreaClass(this.label);
  final String label;
}

enum EvidenceType { fard, intiqal, other }

enum ScheduleColumn {
  description('Description'),
  kanal('Kanal', optional: true),
  marla('Marla', optional: true),
  sarsai('Sarsai', optional: true),
  chosen('Calculated sq ft'),
  percent('%', optional: true),
  type('Classification'),
  mortgage('Mortgage sq ft', optional: true);

  const ScheduleColumn(this.label, {this.optional = false});
  final String label;
  final bool optional;
}

class SchemeArea {
  static const unit = LandUnits.tenThousandthsSqFtPerCentiSarsai;
  static const max = LandUnits.maxKanal * LandUnits.centiSarsaisPerKanal * unit;

  static int? decimal(String text, int places) =>
      NumberFormatters.parseFixedArea(text, places, maximum: max);

  static int? land(String kanal, String marla, String sarsai) {
    final units = LandMath.parseAreaInput(kanal, marla, sarsai);
    if (units == null) return null;
    final total = units * unit;
    return total <= max ? total : null;
  }

  static String display(int? value) => value == null
      ? '—'
      : NumberFormatters.formatSquareFeetFromTenThousandths(
          value,
          includeUnit: true,
        );

  static String composite(int? value) {
    if (value == null) return '—';
    final rounded = (value.abs() + unit ~/ 2) ~/ unit;
    final approximate = value.abs() % unit == 0 ? '' : '~';
    return '$approximate${LandMath.centiSarsaiToComposite(value < 0 ? -rounded : rounded).toShortDisplayString()}';
  }

  static int? percentHundredths(int? area, int? gross) {
    if (area == null || gross == null || gross <= 0) return null;
    return (area * 10000 + gross ~/ 2) ~/ gross;
  }

  static String percentDisplay(int? area, int? gross) {
    final value = percentHundredths(area, gross);
    return value == null
        ? '—'
        : '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}%';
  }
}

class SchemeRow {
  SchemeRow(
    this.id, {
    this.description = '',
    this.sft = '',
    this.kanal = '',
    this.marla = '',
    this.sarsai = '',
    this.percent = '',
    this.mortgageSft = '',
    this.classification = AreaClass.review,
    this.source = '',
    this.needsReview = false,
  });

  final int id;
  String description, sft, kanal, marla, sarsai, percent, mortgageSft, source;
  AreaClass classification;
  bool needsReview;
  bool get hasKms =>
      [kanal, marla, sarsai].any((value) => value.trim().isNotEmpty);
  int? get printedSft => sft.trim().isEmpty ? null : SchemeArea.decimal(sft, 4);
  int? get printedKms => hasKms ? SchemeArea.land(kanal, marla, sarsai) : null;
  int? get mortgage =>
      mortgageSft.trim().isEmpty ? null : SchemeArea.decimal(mortgageSft, 4);
  int? get area =>
      source.isNotEmpty && kanal.trim().isEmpty ? null : printedKms;

  bool get ready =>
      classification != AreaClass.review &&
      !needsReview &&
      description.trim().isNotEmpty &&
      (classification == AreaClass.subtotal || (area ?? 0) > 0);

  bool get isPlotTotal =>
      classification == AreaClass.plot &&
      RegExp(
        r'^total\b.*\bplots?\b',
        caseSensitive: false,
      ).hasMatch(description.trim());

  static AreaClass classify(String description) {
    final text = description.toLowerCase();
    if (RegExp(
      r'total\s+area\s+of\s+scheme|^total\s+(?:scheme\s+)?area$|^gross\s+area$',
    ).hasMatch(text)) {
      return AreaClass.gross;
    }
    final publicUse = RegExp(
      r'road|masjid|mosque|park|green\s*belt|public\s*building|dispensary|solid\s*waste|disposal|sewerage',
    ).hasMatch(text);
    final ownerUse = RegExp(r'plots?|residential|commercial').hasMatch(text);
    if (ownerUse && publicUse) return AreaClass.review;
    if (text.contains('commercial') && !RegExp(r'\bplots?\b').hasMatch(text)) {
      return AreaClass.review;
    }
    if (ownerUse) return AreaClass.plot;
    if (publicUse) return AreaClass.transfer;
    return AreaClass.review;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'sft': sft,
    'k': kanal,
    'm': marla,
    's': sarsai,
    'percent': percent,
    'mortgage': mortgageSft,
    'class': classification.name,
    'source': source,
    'needsReview': needsReview,
  };

  factory SchemeRow.fromJson(Map<String, dynamic> map) => SchemeRow(
    map['id'] as int,
    description: map['description'] as String,
    sft: map['sft'] as String,
    kanal: map['k'] as String,
    marla: map['m'] as String,
    sarsai: map['s'] as String,
    percent: map['percent'] as String,
    mortgageSft: map['mortgage'] as String,
    classification: AreaClass.values.byName(map['class'] as String),
    source: map['source'] as String,
    needsReview: map['needsReview'] as bool,
  );
}

class TransferEvidence {
  TransferEvidence({
    this.type = EvidenceType.fard,
    this.reference = '',
    this.date = '',
    this.recipient = '',
    this.areaSft = '',
    this.crop,
    this.verified = false,
    Map<int, String>? allocations,
  }) : allocations = allocations ?? {};

  EvidenceType type;
  String reference, date, recipient, areaSft;
  String? crop;
  bool verified;
  final Map<int, String> allocations;
  int? get area => SchemeArea.decimal(areaSft, 4);
  String get key =>
      reference.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'reference': reference,
    'date': date,
    'recipient': recipient,
    'area': areaSft,
    'crop': crop,
    'verified': verified,
    'allocations': allocations.map((id, value) => MapEntry('$id', value)),
  };

  factory TransferEvidence.fromJson(Map<String, dynamic> map) =>
      TransferEvidence(
        type: EvidenceType.values.byName(map['type'] as String),
        reference: map['reference'] as String,
        date: map['date'] as String,
        recipient: map['recipient'] as String,
        areaSft: map['area'] as String,
        crop: map['crop'] as String?,
        verified: map['verified'] as bool,
        allocations: (map['allocations'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(int.parse(key), value as String),
        ),
      );
}

class HousingScheme {
  int? id;
  String name = '',
      block = '',
      owner = '',
      recipient = '',
      approval = '',
      location = '';
  bool reviewed = false;
  bool selectedOnly = false;
  String transferredKanal = '', transferredMarla = '', transferredSarsai = '';
  /// Every scanned row (ticked or not) and the ticked ids, so a saved scan can be reopened as it was.
  final scanRows = <SchemeRow>[];
  final scanChecked = <int>{};
  String? scheduleCrop;
  final rows = <SchemeRow>[];
  final evidence = <TransferEvidence>[];
  final columns = ScheduleColumn.values.toList();
  final columnNames = <ScheduleColumn, String>{};
  final hiddenColumns = <ScheduleColumn>{};
  int _nextId = 1;
  int nextRowId() => _nextId++;

  Map<String, dynamic> toJson() => {
    'areaSource': 'kms',
    'name': name,
    'block': block,
    'owner': owner,
    'recipient': recipient,
    'approval': approval,
    'location': location,
    'reviewed': reviewed,
    'selectedOnly': selectedOnly,
    'scanRows': scanRows.map((row) => row.toJson()).toList(),
    'scanChecked': scanChecked.toList(),
    'transferred': {'k': transferredKanal, 'm': transferredMarla, 's': transferredSarsai},
    'crop': scheduleCrop,
    'columns': columns.map((column) => column.name).toList(),
    'labels': columnNames.map((key, value) => MapEntry(key.name, value)),
    'hidden': hiddenColumns.map((column) => column.name).toList(),
    'nextId': _nextId,
    'rows': rows.map((row) => row.toJson()).toList(),
    'evidence': evidence.map((doc) => doc.toJson()).toList(),
  };

  factory HousingScheme.fromJson(Map<String, dynamic> map, {int? id}) {
    final scheme = HousingScheme()
      ..id = id
      ..name = map['name'] as String
      ..block = map['block'] as String
      ..owner = map['owner'] as String
      ..recipient = map['recipient'] as String
      ..approval = map['approval'] as String
      ..location = map['location'] as String? ?? ''
      ..reviewed = map['reviewed'] as bool
      ..selectedOnly = map['selectedOnly'] as bool? ?? false
      ..scheduleCrop = map['crop'] as String?
      ..transferredKanal = (map['transferred'] as Map?)?['k'] as String? ?? ''
      ..transferredMarla = (map['transferred'] as Map?)?['m'] as String? ?? ''
      ..transferredSarsai = (map['transferred'] as Map?)?['s'] as String? ?? ''
      .._nextId = map['nextId'] as int;
    if (map['columns'] case final List saved when map['areaSource'] == 'kms') {
      final ordered = saved
          .cast<String>()
          .map(ScheduleColumn.values.byName)
          .toSet();
      scheme.columns
        ..clear()
        ..addAll({...ordered, ...ScheduleColumn.values});
    }
    if (map['labels'] case final Map<String, dynamic> labels) {
      scheme.columnNames.addAll({
        for (final column in ScheduleColumn.values)
          if (labels[column.name] case final String value
              when column != ScheduleColumn.chosen ||
                  map['areaSource'] == 'kms')
            column: value,
      });
    }
    if (map['hidden'] case final List hidden) {
      scheme.hiddenColumns.addAll(
        hidden
            .cast<String>()
            .where((name) => name != 'sft')
            .map(ScheduleColumn.values.byName)
            .where((column) => column.optional),
      );
    }
    scheme.scanRows.addAll(
      (map['scanRows'] as List? ?? []).cast<Map<String, dynamic>>().map(SchemeRow.fromJson),
    );
    scheme.scanChecked.addAll((map['scanChecked'] as List? ?? []).cast<int>());
    final savedRows = (map['rows'] as List).cast<Map<String, dynamic>>();
    scheme.rows.addAll(savedRows.map(SchemeRow.fromJson));
    scheme.evidence.addAll(
      (map['evidence'] as List).cast<Map<String, dynamic>>().map(
        TransferEvidence.fromJson,
      ),
    );
    if (map['areaSource'] != 'kms') {
      final changed = <int>{};
      for (final (index, row) in scheme.rows.indexed) {
        final basis = savedRows[index]['basis'];
        final printed = row.printedSft;
        final oldUnits = row.printedKms;
        final units = row.area;
        final previous = switch (basis) {
          'squareFeet' => printed,
          'landUnits' => oldUnits,
          _ =>
            printed != null && oldUnits != null && printed != oldUnits
                ? null
                : printed ?? oldUnits,
        };
        if (previous != units || (units == null && printed != null)) {
          changed.add(row.id);
          row.needsReview = true;
        }
      }
      if (changed.isNotEmpty) scheme.reviewed = false;
      for (final doc in scheme.evidence) {
        if (doc.allocations.keys.any(changed.contains)) doc.verified = false;
      }
    }
    final ids = scheme.rows.map((row) => row.id).toSet();
    if (ids.length != scheme.rows.length ||
        ids.any((id) => id < 1 || id >= scheme._nextId)) {
      throw const FormatException('Invalid scheme row identifiers');
    }
    for (final image in [
      scheme.scheduleCrop,
      ...scheme.evidence.map((entry) => entry.crop),
    ]) {
      if (image != null) base64Decode(image);
    }
    return scheme;
  }

  HousingScheme();

  List<String> get scheduleIssues {
    final gross = rows
        .where((row) => row.classification == AreaClass.gross)
        .toList();
    return [
      if (name.trim().isEmpty) 'Enter the scheme name.',
      if (gross.length != 1 || !gross.single.ready)
        'Confirm exactly one gross area.',
      if (!selectedOnly && !rows.any((row) => row.classification == AreaClass.plot && row.ready))
        'Confirm the printed owner-plot area.',
      if (rows.where((row) => row.isPlotTotal).length > 1)
        'Mark duplicate plot totals as excluded subtotals.',
      for (final row in rows)
        if (!row.ready)
          'Review ${row.description.trim().isEmpty ? 'row ${row.id}' : row.description}.',
    ];
  }

  String? evidenceIssue(TransferEvidence doc, {TransferEvidence? replacing}) {
    if (doc.key.isEmpty || doc.recipient.trim().isEmpty) {
      return 'Enter the document reference and recipient.';
    }
    if (recipient.trim().isEmpty ||
        doc.recipient.trim().toLowerCase() != recipient.trim().toLowerCase()) {
      return 'Match the document recipient to the municipal recipient.';
    }
    final parsedDate = DateTime.tryParse(doc.date);
    if (parsedDate == null ||
        parsedDate.toIso8601String().split('T').first != doc.date) {
      return 'Enter a valid date in YYYY-MM-DD format.';
    }
    if (evidence.any(
      (other) =>
          !identical(doc, other) &&
          !identical(replacing, other) &&
          other.type == doc.type &&
          other.key == doc.key,
    )) {
      return 'This document reference is already recorded.';
    }
    final documented = doc.area;
    if (documented == null || documented <= 0) {
      return 'Enter the documented transfer area.';
    }
    if (doc.allocations.isEmpty) {
      return 'Allocate the documented area to transferable rows.';
    }
    var allocated = 0;
    for (final allocation in doc.allocations.entries) {
      final amount = SchemeArea.decimal(allocation.value, 4);
      if (amount == null ||
          amount <= 0 ||
          !rows.any(
            (row) =>
                row.id == allocation.key &&
                row.classification == AreaClass.transfer &&
                row.ready,
          )) {
        return 'Each allocation needs a positive area and a reviewed transferable row.';
      }
      allocated += amount;
      if (allocated > documented) {
        return 'Allocations exceed the documented area.';
      }
    }
    if (allocated != documented) {
      return 'Allocate the full documented area before verifying.';
    }
    return null;
  }

  SchemeTotals get totals => SchemeTotals(this);
}

class SchemeTotals {
  SchemeTotals(this.scheme);
  final HousingScheme scheme;

  Iterable<SchemeRow> get eligible => scheme.rows.where((row) => row.ready);
  Iterable<SchemeRow> get dueRows =>
      eligible.where((row) => row.classification == AreaClass.transfer);
  int? get gross {
    final rows = scheme.rows
        .where((row) => row.classification == AreaClass.gross)
        .toList();
    return rows.length == 1 && rows.single.ready ? rows.single.area : null;
  }

  int get nonPlot => eligible
      .where(
        (row) =>
            row.classification == AreaClass.transfer ||
            row.classification == AreaClass.other,
      )
      .fold(0, (sum, row) => sum + row.area!);
  int? get printedPlots {
    final plots = eligible.where((row) => row.classification == AreaClass.plot);
    if (plots.isEmpty) return null;
    return plots.where((row) => row.isPlotTotal).firstOrNull?.area ??
        plots.fold<int>(0, (sum, row) => sum + row.area!);
  }

  int? get calculatedPlots => gross == null ? null : gross! - nonPlot;
  int? get mapDifference {
    final calculated = calculatedPlots;
    final printed = printedPlots;
    return calculated == null || printed == null ? null : calculated - printed;
  }
  int get due => dueRows.fold(0, (sum, row) => sum + row.area!);
  int? get grossLessTransferable => gross == null ? null : gross! - due;
  int get mortgage =>
      scheme.rows.fold(0, (sum, row) => sum + (row.mortgage ?? 0));

  bool isVerified(TransferEvidence doc) =>
      doc.verified && scheme.evidenceIssue(doc) == null;
  int transferred(SchemeRow row) => scheme.evidence
      .where(isVerified)
      .fold(
        0,
        (sum, doc) =>
            sum + (SchemeArea.decimal(doc.allocations[row.id] ?? '', 4) ?? 0),
      );
  int outstanding(SchemeRow row) =>
      (row.area! - transferred(row)).clamp(0, row.area!);
  int excess(SchemeRow row) =>
      (transferred(row) - row.area!).clamp(0, SchemeArea.max);
  int get verified => dueRows.fold(0, (sum, row) => sum + transferred(row));
  int get remaining => dueRows.fold(0, (sum, row) => sum + outstanding(row));
  int get overage => dueRows.fold(0, (sum, row) => sum + excess(row));
  List<String> get issues => [
    if (!scheme.reviewed) 'Schedule review is pending.',
    ...scheme.scheduleIssues,
    for (final row in scheme.rows)
      if (row.mortgageSft.trim().isNotEmpty && row.mortgage == null)
        'Review mortgage amount for ${row.description}.',
    if (mapDifference case final difference? when difference != 0)
      'Map reconciliation differs by ${SchemeArea.display(difference)}.',
    if (grossLessTransferable case final balance? when balance < 0)
      'Transferable area exceeds the total area.',
    for (final doc in scheme.evidence)
      if (!isVerified(doc))
        'Pending ${doc.type.name} ${doc.reference}: ${scheme.evidenceIssue(doc) ?? 'officer verification required'}.',
  ];
}
