import 'package:flutter/material.dart';
import '../../../core/constants/land_units.dart';
import '../../../core/utils/number_formatters.dart';
import '../../../data/models/measurement_entry.dart';
import '../logic/land_math.dart';

class LandRowModel {
  final String keyId;
  int? dbId;
  EntryOperation operation;
  String purpose;

  int kanal;
  int marla;
  int sarsaiCenti;

  String? kanalError;
  String? marlaError;
  String? sarsaiError;

  final TextEditingController purposeController;
  final TextEditingController kanalController;
  final TextEditingController marlaController;
  final TextEditingController sarsaiController;

  final FocusNode purposeFocus;
  final FocusNode kanalFocus;
  final FocusNode marlaFocus;
  final FocusNode sarsaiFocus;

  LandRowModel({
    required this.keyId,
    this.dbId,
    this.operation = EntryOperation.add,
    this.purpose = 'Nil',
    this.kanal = 0,
    this.marla = 0,
    this.sarsaiCenti = 0,
  })  : purposeController = TextEditingController(text: purpose),
        kanalController = TextEditingController(text: kanal == 0 ? '' : kanal.toString()),
        marlaController = TextEditingController(text: marla == 0 ? '' : marla.toString()),
        sarsaiController = TextEditingController(
          text: sarsaiCenti == 0 ? '' : NumberFormatters.formatSarsaiFromCenti(sarsaiCenti),
        ),
        purposeFocus = FocusNode(),
        kanalFocus = FocusNode(),
        marlaFocus = FocusNode(),
        sarsaiFocus = FocusNode() {
    purposeFocus.addListener(() {
      if (!purposeFocus.hasFocus && purposeController.text.trim().isEmpty) {
        purposeController.text = 'Nil';
      }
    });
    _attachSelectionOnFocus(kanalFocus, kanalController);
    _attachSelectionOnFocus(marlaFocus, marlaController);
    _attachSelectionOnFocus(sarsaiFocus, sarsaiController);
  }

  static void _attachSelectionOnFocus(FocusNode focus, TextEditingController controller) {
    focus.addListener(() {
      if (focus.hasFocus) {
        if (controller.text == '0' || controller.text == '0.0' || controller.text == '0.00' || controller.text == 'Nil') {
          controller.clear();
        } else if (controller.text.isNotEmpty) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      }
    });
  }

  bool get isSubtract => operation == EntryOperation.subtract;

  int get centiSarsai => LandMath.rowToCentiSarsai(
        kanal: kanal,
        marla: marla,
        sarsaiCenti: sarsaiCenti,
      );

  int get sqFtTenThousandths => LandMath.rowUnitsToSqFtTenThousandths(
        centiSarsai,
        isSubtract: isSubtract,
      );

  String get sqFtFormatted =>
      NumberFormatters.formatSquareFeetFromTenThousandths(sqFtTenThousandths);

  bool get hasError => kanalError != null || marlaError != null || sarsaiError != null;

  void validate() {
    final k = kanalController.text;
    final m = marlaController.text;
    final s = sarsaiController.text;
    kanalError = NumberFormatters.parseFixedArea(k, 2, maximum: LandUnits.maxKanal * 100) == null ? '0..1M' : null;
    marlaError = NumberFormatters.parseFixedArea(m, 2, maximum: 1999) == null ? '0..19.99' : null;
    sarsaiError = NumberFormatters.parseSarsaiToCenti(s) == null ? '0..8.99' : null;
    if (hasError) return;
    final units = LandMath.parseAreaInput(k, m, s);
    if (units == null) {
      kanalError = 'Area too large';
      return;
    }
    final area = LandMath.centiSarsaiToComposite(units);
    kanal = area.kanal;
    marla = area.marla;
    sarsaiCenti = area.sarsaiCenti;
  }

  void dispose() {
    purposeController.dispose();
    kanalController.dispose();
    marlaController.dispose();
    sarsaiController.dispose();
    purposeFocus.dispose();
    kanalFocus.dispose();
    marlaFocus.dispose();
    sarsaiFocus.dispose();
  }

  MeasurementEntry toMeasurementEntry({required int sortOrder, int? calculationId}) {
    return MeasurementEntry(
      id: dbId,
      calculationId: calculationId,
      sortOrder: sortOrder,
      purpose: purpose.trim().isEmpty ? 'Nil' : purpose.trim(),
      operation: operation,
      kanal: kanal,
      marla: marla,
      sarsaiCenti: sarsaiCenti,
    );
  }
}
