import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/scheme_catalog.dart';
import '../../land/logic/land_math.dart';
import '../logic/scheme.dart';
import 'crop_image_screen.dart';

const areaKeyboard = TextInputType.numberWithOptions(decimal: true);

Widget schemeSuggestionField({
  Key? key,
  String? label,
  String? hint,
  required String value,
  required Iterable<String> suggestions,
  required ValueChanged<String> onChanged,
  ValueChanged<String>? onSelected,
  required int maxLength,
}) => Autocomplete<String>(
  key: key,
  initialValue: TextEditingValue(text: value),
  optionsBuilder: (input) => SchemeCatalog.suggest(suggestions, input.text),
  onSelected: onSelected ?? onChanged,
  fieldViewBuilder: (context, controller, focus, submit) => TextField(
    controller: controller, focusNode: focus, onChanged: onChanged,
    onSubmitted: (_) => submit(), maxLength: maxLength,
    decoration: InputDecoration(labelText: label, hintText: hint, counterText: ''),
  ),
);

Widget schemeField(
  String label,
  String value,
  ValueChanged<String> changed, {
  TextInputType? keyboard,
  int? maxLength,
  Key? key,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextFormField(
    key: key,
    initialValue: value,
    onChanged: changed,
    keyboardType: keyboard,
    maxLength: maxLength,
    decoration: InputDecoration(labelText: label, counterText: ''),
  ),
);

Future<T?> schemeDialog<T>(
  BuildContext context,
  String title,
  Widget Function(BuildContext) builder,
) => showDialog<T>(
  context: context,
  builder: (context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            builder(context),
          ],
        ),
      ),
    ),
  ),
);

Widget cropPreview(BuildContext context, String encoded, String label) =>
    OutlinedButton.icon(
      icon: const Icon(Icons.image_outlined),
      label: Text(label),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: InteractiveViewer(
            child: Image.memory(
              base64Decode(encoded),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Image unavailable.'),
              ),
            ),
          ),
        ),
      ),
    );

class SchemeAreaField extends StatefulWidget {
  const SchemeAreaField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label, value;
  final ValueChanged<String> onChanged;

  @override
  State<SchemeAreaField> createState() => _SchemeAreaFieldState();
}

class _SchemeAreaFieldState extends State<SchemeAreaField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enterKms() async {
    var k = '', m = '', s = '';
    String? error;
    final amount = await schemeDialog<int>(
      context,
      'Enter Kanal / Marla / Sarsai',
      (dialog) => StatefulBuilder(
        builder: (context, change) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            schemeField(
              'Kanal',
              '',
              (value) => k = value,
              keyboard: areaKeyboard,
            ),
            schemeField(
              'Marla',
              '',
              (value) => m = value,
              keyboard: areaKeyboard,
            ),
            schemeField(
              'Sarsai',
              '',
              (value) => s = value,
              keyboard: areaKeyboard,
            ),
            if (error != null) Text(error!),
            FilledButton(
              onPressed: () {
                final result = SchemeArea.land(k, m, s);
                if (result == null) {
                  change(
                    () => error =
                        'Enter valid land units with up to two decimal places.',
                  );
                } else {
                  Navigator.pop(dialog, result);
                }
              },
              child: const Text('Use area'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || amount == null) return;
    final text =
        '${amount ~/ 10000}.${(amount % 10000).toString().padLeft(4, '0')}';
    _controller.text = text;
    widget.onChanged(text);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _controller,
      keyboardType: areaKeyboard,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: TextButton(
          onPressed: _enterKms,
          child: const Text('K/M/S'),
        ),
      ),
    ),
  );
}

/// Plain decimal text (no thousands separator) for an area in ten-thousandths of a sq ft.
String plainSquareFeet(int? area) {
  if (area == null) return '';
  final whole = area ~/ 10000;
  final fraction = (area % 10000).toString().padLeft(4, '0').replaceAll(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}

/// Owns the row editor's text controllers so they are disposed with the dialog, after it has closed.
class _RowControllers extends StatefulWidget {
  const _RowControllers({required this.row, required this.builder});
  final SchemeRow row;
  final Widget Function(BuildContext context, List<TextEditingController> controllers) builder;

  @override
  State<_RowControllers> createState() => _RowControllersState();
}

class _RowControllersState extends State<_RowControllers> {
  late final controllers = [
    TextEditingController(text: widget.row.kanal),
    TextEditingController(text: widget.row.marla),
    TextEditingController(text: widget.row.sarsai),
    TextEditingController(
      text: widget.row.sft.isNotEmpty ? widget.row.sft : plainSquareFeet(widget.row.printedKms),
    ),
    TextEditingController(text: widget.row.percent),
  ];

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, controllers);
}

Future<SchemeRow?> editSchemeRow(BuildContext context, SchemeRow original) {
  final row = SchemeRow.fromJson(original.toJson());
  return schemeDialog<SchemeRow>(
    context,
    'Area schedule row',
    (dialog) => _RowControllers(
      row: row,
      builder: (context, controllers) {
        final [kanal, marla, sarsai, sft, percent] = controllers;
        return StatefulBuilder(
      builder: (context, update) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (row.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Scanned: ${row.source}'),
            ),
          schemeSuggestionField(
            label: 'Area title',
            value: row.description,
            suggestions: SchemeCatalog.areaTitles,
            onChanged: (text) => row.description = text,
            onSelected: (title) => update(() {
              row.description = title;
              row.classification = SchemeRow.classify(title);
            }),
            maxLength: 240,
          ),
          DropdownButtonFormField<AreaClass>(
            key: ValueKey(row.classification),
            initialValue: row.classification,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Classification'),
            items: [
              for (final item in AreaClass.values)
                DropdownMenuItem(value: item, child: Text(item.label)),
            ],
            onChanged: (value) => update(() => row.classification = value!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (label, controller) in [
                ('Kanal', kanal),
                ('Marla', marla),
                ('Sarsai', sarsai),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 5, bottom: 10),
                    child: TextField(
                      controller: controller,
                      keyboardType: areaKeyboard,
                      decoration: InputDecoration(labelText: label),
                      // Typing Kanal/Marla/Sarsai recalculates the square feet.
                      onChanged: (_) => update(() {
                        row
                          ..kanal = kanal.text
                          ..marla = marla.text
                          ..sarsai = sarsai.text;
                        final area = row.printedKms;
                        if (area != null) {
                          sft.text = plainSquareFeet(area);
                          row.sft = sft.text;
                        }
                      }),
                    ),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 5, bottom: 10),
                  child: TextField(
                    controller: sft,
                    keyboardType: areaKeyboard,
                    decoration: const InputDecoration(labelText: 'Square feet'),
                    // Typing the square feet fills Kanal/Marla/Sarsai.
                    onChanged: (text) => update(() {
                      row.sft = text;
                      final value = SchemeArea.decimal(text, 4);
                      if (value == null) return;
                      final units = (value + SchemeArea.unit ~/ 2) ~/ SchemeArea.unit;
                      final c = LandMath.centiSarsaiToComposite(units);
                      kanal.text = '${c.kanal}';
                      marla.text = '${c.marla}';
                      sarsai.text = c.sarsaiFormatted;
                      row
                        ..kanal = kanal.text
                        ..marla = marla.text
                        ..sarsai = sarsai.text;
                    }),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 5, bottom: 10),
                  child: TextField(
                    controller: percent,
                    keyboardType: areaKeyboard,
                    decoration: const InputDecoration(labelText: '% (empty = calculated)'),
                    onChanged: (text) => update(() => row.percent = text.replaceAll('%', '').trim()),
                  ),
                ),
              ),
            ],
          ),
          Text('Calculated square feet: ${SchemeArea.display(row.area)}'),
          SchemeAreaField(
            label: 'Mortgage sq ft (optional)',
            value: row.mortgageSft,
            onChanged: (text) => update(() => row.mortgageSft = text),
          ),
          if (row.source.isNotEmpty && row.kanal.trim().isEmpty)
            const Text(
              'Check the Kanal cell and enter 0 if the map shows zero.',
            ),
          if (original.needsReview)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I checked the unclear cells against the map'),
              value: !row.needsReview,
              onChanged: (value) =>
                  update(() => row.needsReview = value != true),
            ),
          if (!row.ready)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'This row will stay pending until its description, classification, and area are resolved.',
              ),
            ),
          if (row.mortgageSft.trim().isNotEmpty && row.mortgage == null)
            const Text('Enter a valid mortgage area or clear the field.'),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, row),
                child: const Text('Apply row'),
              ),
            ],
          ),
        ],
      ),
    );
      },
    ),
  );
}

Future<TransferEvidence?> editEvidence(
  BuildContext context,
  HousingScheme scheme,
  TransferEvidence? original,
) {
  final doc = original == null
      ? (TransferEvidence()..recipient = scheme.recipient)
      : TransferEvidence.fromJson(original.toJson());
  return schemeDialog<TransferEvidence>(
    context,
    'Transfer evidence',
    (dialog) => StatefulBuilder(
      builder: (context, update) {
        void change(VoidCallback apply) => update(() {
          apply();
          doc.verified = false;
        });
        final issue = scheme.evidenceIssue(doc, replacing: original);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<EvidenceType>(
              initialValue: doc.type,
              decoration: const InputDecoration(labelText: 'Document type'),
              items: [
                for (final type in EvidenceType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(switch (type) {
                      EvidenceType.fard => 'Fard',
                      EvidenceType.intiqal => 'Intiqal',
                      EvidenceType.other => 'Other',
                    }),
                  ),
              ],
              onChanged: (type) => change(() => doc.type = type!),
            ),
            const SizedBox(height: 12),
            schemeField(
              'Document reference',
              doc.reference,
              (text) => change(() => doc.reference = text),
              maxLength: 120,
            ),
            schemeField(
              'Date (YYYY-MM-DD)',
              doc.date,
              (text) => change(() => doc.date = text),
              keyboard: TextInputType.datetime,
              maxLength: 10,
            ),
            schemeField(
              'Recipient as printed',
              doc.recipient,
              (text) => change(() => doc.recipient = text),
              maxLength: 150,
            ),
            SchemeAreaField(
              label: 'Documented transfer sq ft',
              value: doc.areaSft,
              onChanged: (text) => change(() => doc.areaSft = text),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final camera in [false, if (Platform.isAndroid) true])
                  OutlinedButton.icon(
                    icon: Icon(
                      camera ? Icons.camera_alt_outlined : Icons.photo_outlined,
                    ),
                    label: Text(
                      camera ? 'Photograph evidence' : 'Choose evidence photo',
                    ),
                    onPressed: () async {
                      final crop = await CropImageScreen.pick(
                        dialog,
                        camera: camera,
                      );
                      if (crop != null && dialog.mounted) {
                        change(() => doc.crop = base64Encode(crop.preview));
                      }
                    },
                  ),
                if (doc.crop case final crop?)
                  cropPreview(context, crop, 'View evidence crop'),
                if (doc.crop != null)
                  TextButton(
                    onPressed: () => change(() => doc.crop = null),
                    child: const Text('Remove image'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Allocations', style: Theme.of(context).textTheme.titleMedium),
            if (scheme.totals.dueRows.isEmpty)
              const Text(
                'Review at least one transferable schedule row first.',
              ),
            for (final row in scheme.totals.dueRows)
              SchemeAreaField(
                key: ValueKey(row.id),
                label: '${row.description} (sq ft)',
                value: doc.allocations[row.id] ?? '',
                onChanged: (value) => change(() {
                  if (value.trim().isEmpty) {
                    doc.allocations.remove(row.id);
                  } else {
                    doc.allocations[row.id] = value;
                  }
                }),
              ),
            for (final id in doc.allocations.keys.where(
              (id) => !scheme.totals.dueRows.any((row) => row.id == id),
            ))
              ListTile(
                title: Text('Allocation to unavailable row $id'),
                trailing: TextButton(
                  onPressed: () => change(() => doc.allocations.remove(id)),
                  child: const Text('Remove'),
                ),
              ),
            if (issue != null)
              Text(
                issue,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Officer verified the document and category allocations',
              ),
              value: doc.verified && issue == null,
              onChanged: issue == null
                  ? (value) => update(() => doc.verified = value == true)
                  : null,
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialog, doc),
                  child: const Text('Apply evidence'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

Future<void> editExportLayout(
  BuildContext context,
  HousingScheme scheme,
) async {
  final order = scheme.columns.toList();
  final names = Map<ScheduleColumn, String>.of(scheme.columnNames);
  final hidden = Set<ScheduleColumn>.of(scheme.hiddenColumns);
  final applied = await schemeDialog<bool>(
    context,
    'Report columns',
    (dialog) => StatefulBuilder(
      builder: (context, update) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Use the arrows to reorder columns. Optional columns can be hidden.',
          ),
          for (final (index, column) in order.indexed)
            Row(
              key: ValueKey(column),
              children: [
                Expanded(
                  child: schemeField(
                    column.label,
                    names[column] ?? column.label,
                    (value) {
                      if (value.trim().isEmpty) {
                        names.remove(column);
                      } else {
                        names[column] = value.trim();
                      }
                    },
                    maxLength: 40,
                  ),
                ),
                if (column.optional)
                  Checkbox(
                    value: !hidden.contains(column),
                    semanticLabel: 'Show ${column.label}',
                    onChanged: (shown) => update(
                      () => shown == true
                          ? hidden.remove(column)
                          : hidden.add(column),
                    ),
                  ),
                IconButton(
                  tooltip: 'Move ${column.label} up',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: index == 0
                      ? null
                      : () => update(
                          () => order.insert(index - 1, order.removeAt(index)),
                        ),
                ),
                IconButton(
                  tooltip: 'Move ${column.label} down',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: index + 1 == order.length
                      ? null
                      : () => update(
                          () => order.insert(index + 1, order.removeAt(index)),
                        ),
                ),
              ],
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Apply layout'),
          ),
        ],
      ),
    ),
  );
  if (applied == true) {
    scheme.columns
      ..clear()
      ..addAll(order);
    scheme.columnNames
      ..clear()
      ..addAll(names);
    scheme.hiddenColumns
      ..clear()
      ..addAll(hidden);
  }
}
