import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:plotmetric/data/local/app_database.dart';
import 'package:plotmetric/features/ocr/hocr.dart';
import 'package:plotmetric/features/ocr/image_adjust.dart';
import 'package:plotmetric/features/ocr/ocr_comparison.dart';
import 'package:plotmetric/features/ocr/ocr_models.dart';
import 'package:plotmetric/features/ocr/ocr_provider.dart';
import 'package:plotmetric/features/ocr/ocr_registry.dart';
import 'package:plotmetric/features/ocr/ocr_settings.dart';
import 'package:plotmetric/features/ocr/ocr_table.dart';
import 'package:plotmetric/features/ocr/presentation/ocr_compare_screen.dart';
import 'package:plotmetric/features/ocr/presentation/ocr_panel.dart';
import 'package:plotmetric/features/ocr/providers/azure_layout_provider.dart';
import 'package:plotmetric/features/ocr/providers/paddle_not_installed_provider.dart';
import 'package:plotmetric/features/schemes/logic/scheme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// An engine that returns fixed words (no real OCR), so selection, comparison and merging can be tested.
class FakeProvider extends OcrProvider {
  FakeProvider(this.id, this.name, this.words, {this.isOnline = false, this.status = const OcrAvailability.ready()});

  @override
  final String id;
  @override
  final String name;
  final List<OcrWord> words;
  final bool isOnline;
  final OcrAvailability status;
  final reads = <String>[];

  @override
  String get version => 'fake 1.0';
  @override
  Set<String> get platforms => const {'android', 'windows'};
  @override
  bool get online => isOnline;
  @override
  Future<OcrAvailability> availability() async => status;
  @override
  Future<OcrRun> recognize(String imagePath, {OcrCancelToken? cancel}) => runTimed(this, () async {
    reads.add(imagePath);
    return (words: words, rawText: words.map((w) => w.text).join(' '), warnings: const <String>[]);
  }, cancel: cancel);
}

class MemorySettings extends OcrSettings {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

OcrWord w(String text, double x, double y, {double? width, double? confidence}) =>
    OcrWord(text: text, x: x, y: y, height: 14, width: width, confidence: confidence);

/// A tiny area schedule: header plus two rows (K, M, S columns).
List<OcrWord> schedule({String roadKanal = '13', String roadMarla = '3'}) => [
  w('S.NO', 20, 10), w('DESCRIPTION', 100, 10), w('SFT', 240, 10), w('K', 275, 10), w('M', 310, 10), w('S', 345, 10),
  w('1', 20, 40), w('TOTAL AREA', 100, 40), w('283140', 240, 40), w('52', 275, 40), w('0', 310, 40), w('0', 345, 40),
  w('2', 20, 75), w('TOTAL ROAD AREA', 100, 75), w('71670', 240, 75), w(roadKanal, 275, 75), w(roadMarla, 310, 75), w('2', 345, 75),
];

void main() {
  group('hOCR (Tesseract)', () {
    const hocr = '''
<div class='ocr_page' title='image "crop.png"; bbox 0 0 800 400'>
 <span class='ocr_line' title='bbox 10 20 300 44'>
  <span class='ocrx_word' id='word_1_1' title='bbox 10 20 90 44; x_wconf 96'>TOTAL</span>
  <span class='ocrx_word' id='word_1_2' title='bbox 100 20 160 44; x_wconf 71'><strong>AREA</strong></span>
  <span class='ocrx_word' id='word_1_3' title='bbox 200 20 240 44; x_wconf 40'>R&amp;D</span>
 </span>
</div>''';

    test('words, boxes and confidence are read', () {
      final words = parseHocr(hocr);
      expect(words.map((word) => word.text), ['TOTAL', 'AREA', 'R&D']);
      expect(words.first.x, 50);
      expect(words.first.y, 32);
      expect(words.first.width, 80);
      expect(words.first.height, 24);
      expect(words.first.confidence, closeTo(0.96, 0.001));
      expect(words[2].confidence, closeTo(0.40, 0.001));
    });

    test('text without word boxes gives nothing rather than invented positions', () {
      expect(parseHocr('plain text only'), isEmpty);
    });
  });

  group('table reconstruction input', () {
    test('a region holding several cells is split across its width, not invented', () {
      final pieces = tableWordsFrom([w('TOTAL AREA 52 0 0', 200, 40, width: 340)]);
      expect(pieces.map((piece) => piece.text), ['TOTAL', 'AREA', '52', '0', '0']);
      final xs = pieces.map((piece) => piece.x).toList();
      expect(xs, orderedEquals([...xs]..sort()));
      expect(xs.first, greaterThan(30));
      expect(xs.last, lessThan(370));
    });

    test('a region without a width is kept whole', () {
      expect(tableWordsFrom([w('TOTAL AREA', 100, 40)]).single.text, 'TOTAL AREA');
    });

    test('rows come from any engine through the same reconstruction', () {
      final run = OcrRun(
        engineId: 'a',
        engineName: 'A',
        engineVersion: '1',
        online: false,
        words: schedule(),
        rawText: '',
        duration: Duration.zero,
      );
      final rows = rowsFromRun(run);
      expect(rows.map((row) => row.description), ['TOTAL AREA', 'TOTAL ROAD AREA']);
      expect((rows[1].kanal, rows[1].marla, rows[1].sarsai), ('13', '3', '2'));
    });

    test('a failed run reconstructs nothing', () {
      const run = OcrRun(
        engineId: 'a', engineName: 'A', engineVersion: '1', online: false,
        words: [], rawText: '', duration: Duration.zero, error: 'boom',
      );
      expect(rowsFromRun(run), isEmpty);
    });
  });

  group('registry and selection', () {
    test('Run All reads the same crop with every ready offline engine, never online or unready ones', () async {
      final a = FakeProvider('a', 'A', schedule());
      final b = FakeProvider('b', 'B', schedule(roadKanal: '14'));
      final online = FakeProvider('azure', 'Azure', schedule(), isOnline: true);
      final missing = FakeProvider('c', 'C', schedule(), status: const OcrAvailability.setupRequired('needs a model'));
      final registry = OcrRegistry([a, online, missing, b], settings: MemorySettings());
      final runs = await registry.runAllOffline('crop.png').toList();
      expect(runs.map((run) => run.engineId), ['a', 'b']);
      expect(a.reads, ['crop.png']);
      expect(b.reads, ['crop.png']);
      expect(online.reads, isEmpty);
      expect(missing.reads, isEmpty);
    });

    test('cancelling stops before the next engine', () async {
      final cancel = OcrCancelToken();
      final a = FakeProvider('a', 'A', schedule());
      final b = FakeProvider('b', 'B', schedule());
      final registry = OcrRegistry([a, b], settings: MemorySettings());
      final runs = <OcrRun>[];
      await for (final run in registry.runAllOffline('crop.png', cancel: cancel)) {
        runs.add(run);
        cancel.cancel();
      }
      expect(runs.map((run) => run.engineId), ['a']);
      expect(b.reads, isEmpty);
    });

    test('the saved engine is preferred while it is usable, otherwise the first offline engine', () async {
      final settings = MemorySettings();
      final a = FakeProvider('a', 'A', schedule());
      final b = FakeProvider('b', 'B', schedule());
      final registry = OcrRegistry([a, b], settings: settings);
      expect((await registry.preferred())!.id, 'a');
      await settings.setPreferredEngine('b');
      expect((await registry.preferred())!.id, 'b');
      final broken = FakeProvider('b', 'B', schedule(), status: const OcrAvailability.setupRequired('gone'));
      expect((await OcrRegistry([a, broken], settings: settings).preferred())!.id, 'a');
    });

    test('PaddleOCR is shown as disabled with a reason, and cannot run', () async {
      const paddle = PaddleNotInstalledProvider();
      final status = await paddle.availability();
      expect(status.isReady, isFalse);
      expect(status.reason, contains('compatibility report'));
      final run = await paddle.recognize('crop.png');
      expect(run.failed, isTrue);
      expect(run.words, isEmpty);
    });
  });

  group('Azure (online)', () {
    const azureBody = '''
{"analyzeResult":{"pages":[{"unit":"pixel","words":[
 {"content":"TOTAL","polygon":[10,10,60,10,60,30,10,30],"confidence":0.99},
 {"content":"52","polygon":[200,10,230,10,230,30,200,30],"confidence":0.8}]}]}}''';

    test('words and confidence are read from the layout result', () {
      final words = parseAzureLayout(azureBody);
      expect(words.map((word) => word.text), ['TOTAL', '52']);
      expect(words.first.confidence, 0.99);
      expect(words[1].x, 215);
    });

    Future<(AzureLayoutProvider, MemorySettings, List<http.Request>, File)> setup(http.Response Function(http.Request) answer) async {
      final folder = await Directory.systemTemp.createTemp('azure_test_');
      addTearDown(() => folder.delete(recursive: true));
      final file = await File(p.join(folder.path, 'crop.png')).writeAsBytes([1, 2, 3]);
      final settings = MemorySettings()..values[OcrSettings.azureProxyKey] = 'https://proxy.example/layout';
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return answer(request);
      });
      return (AzureLayoutProvider(settings: settings, client: client), settings, requests, file);
    }

    test('nothing is uploaded without consent for that exact file', () async {
      final (provider, _, requests, file) = await setup((_) => http.Response(azureBody, 200));
      final run = await provider.recognize(file.path);
      expect(run.failed, isTrue);
      expect(run.error, contains('not agreed'));
      expect(requests, isEmpty);
    });

    test('with consent the crop is sent once, as base64, with no key in the request', () async {
      final (provider, _, requests, file) = await setup((_) => http.Response(azureBody, 200));
      provider.grantConsent(file.path);
      final run = await provider.recognize(file.path);
      expect(run.failed, isFalse);
      expect(run.online, isTrue);
      expect(run.words, hasLength(2));
      expect(requests, hasLength(1));
      expect(requests.single.url.toString(), 'https://proxy.example/layout');
      expect(requests.single.headers.keys.map((key) => key.toLowerCase()), isNot(contains('ocp-apim-subscription-key')));
      expect((jsonDecode(requests.single.body) as Map)['image'], base64Encode([1, 2, 3]));
      // Consent was for one upload only.
      final again = await provider.recognize(file.path);
      expect(again.failed, isTrue);
      expect(requests, hasLength(1));
    });

    test('rate limits and refusals are reported, not hidden', () async {
      final (provider, _, _, file) = await setup((_) => http.Response('', 429, headers: {'retry-after': '30'}));
      provider.grantConsent(file.path);
      final run = await provider.recognize(file.path);
      expect(run.error, allOf(contains('rate limiting'), contains('30')));
    });

    test('without a proxy address it is "setup required", never ready', () async {
      final provider = AzureLayoutProvider(settings: MemorySettings());
      final status = await provider.availability();
      if (Platform.isWindows || Platform.isAndroid) {
        expect(status.status, OcrStatus.setupRequired);
      }
      expect(provider.online, isTrue);
    });
  });

  group('combining results', () {
    List<SchemeRow> rowsOf(List<OcrWord> words) => rowsFromRun(
      OcrRun(engineId: 'x', engineName: 'X', engineVersion: '1', online: false, words: words, rawText: '', duration: Duration.zero),
    );

    test('a cell taken from another engine keeps its source, and typed cells are marked as typed', () {
      final first = rowsOf(schedule(roadKanal: '18'));
      final second = rowsOf(schedule(roadKanal: '13'));
      final table = CombinedTable.from(first, 'a');
      expect(table.rows[1].row.kanal, '18');
      table.takeCell(1, ResultField.kanal, second[1], 'b');
      table.editCell(1, ResultField.marla, '4');
      expect(table.rows[1].row.kanal, '13');
      expect(table.rows[1].row.marla, '4');
      expect(table.sources()['2.kanal'], 'b');
      expect(table.sources()['2.marla'], manualSource);
      expect(table.sources()['2.sarsai'], 'a');
      // The other engine's own rows are unchanged.
      expect(first[1].kanal, '18');
    });

    test('the scoring counts correct, misplaced, missing and wrong cells', () {
      const expected = [
        ExpectedRow('TOTAL AREA', kanal: '52', marla: '0', sarsai: '0', sft: '283140'),
        ExpectedRow('TOTAL ROAD AREA', kanal: '13', marla: '3', sarsai: '2', sft: '71670'),
      ];
      final good = rowsOf(schedule());
      final score = scoreRows(expected, good);
      expect(score.rowsRecognised, 2);
      expect(score.cellsCorrect, score.expectedCells);

      // Kanal and Marla swapped, and Sarsai missing.
      final bad = rowsOf([
        ...schedule(roadKanal: '3', roadMarla: '13').where((word) => word.y < 70),
        w('2', 20, 75), w('TOTAL ROAD AREA', 100, 75), w('71670', 240, 75), w('3', 275, 75), w('13', 310, 75),
      ]);
      final worse = scoreRows(expected, bad);
      expect(worse.cellsInWrongColumn, 2);
      expect(worse.cellsMissing, 1);
      expect(worse.cellsCorrect, lessThan(good.length * 4));
    });

    test('testing mode reads a typed verified table', () {
      final expected = ExpectedRow.parse('TOTAL AREA, 52, 0, 0, 283140\nROAD, 13, 3');
      expect(expected, hasLength(2));
      expect(expected[0].sft, '283140');
      expect(expected[1].sarsai, '');
    });
  });

  group('image adjustments', () {
    test('defaults change nothing and the colour matrix applies brightness and contrast', () {
      expect(const ImageAdjustments().isDefault, isTrue);
      final matrix = const ImageAdjustments(brightness: 0.1, contrast: 1.5).colorMatrix();
      expect(matrix.length, 20);
      expect(matrix[0], 1.5);
      expect(matrix[4], closeTo(128 * (1 - 1.5) + 25.5, 0.001));
      final gray = const ImageAdjustments(grayscale: true).colorMatrix();
      expect(gray[0], closeTo(0.2126, 0.0001));
      expect(gray[5], closeTo(0.2126, 0.0001));
    });

    test('sharpening raises the contrast of an edge and leaves alpha and borders alone', () {
      final pixels = List<int>.generate(5 * 5 * 4, (i) => i % 4 == 3 ? 255 : 100);
      for (var y = 0; y < 5; y++) {
        for (var x = 3; x < 5; x++) {
          for (var c = 0; c < 3; c++) {
            pixels[(y * 5 + x) * 4 + c] = 200;
          }
        }
      }
      final out = sharpenRgba(Uint8List.fromList(pixels), 5, 5);
      expect(out[(2 * 5 + 2) * 4], lessThan(100)); // dark side of the edge gets darker
      expect(out[(2 * 5 + 3) * 4], greaterThan(200)); // bright side gets brighter
      expect(out[(2 * 5 + 2) * 4 + 3], 255);
      expect(out[0], 100);
    });
  });

  test('the preferred engine is stored in SQLite and survives reopening (database upgrade to v5)', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final build = await Directory('build').create(recursive: true);
    final folder = await build.createTemp('ocr_settings_test_');
    addTearDown(() async {
      await AppDatabase.instance.close();
      await folder.delete(recursive: true);
    });
    await databaseFactory.setDatabasesPath(folder.absolute.path);
    final legacy = await databaseFactory.openDatabase(
      p.join(folder.absolute.path, AppDatabase.databaseName),
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE calculations (id INTEGER PRIMARY KEY, title TEXT)');
        },
      ),
    );
    await legacy.close();
    final settings = OcrSettings();
    expect(await settings.preferredEngine(), isNull);
    await settings.setPreferredEngine('tesseract');
    expect(await settings.preferredEngine(), 'tesseract');
    await AppDatabase.instance.close();
    expect(await OcrSettings().preferredEngine(), 'tesseract');
    await settings.write(OcrSettings.preferredEngineKey, null);
    expect(await settings.preferredEngine(), isNull);
  });

  group('screens', () {
    testWidgets('the selector lists engines, explains disabled ones, and reads only the confirmed crop', (tester) async {
      final good = FakeProvider('good', 'Good Engine', schedule());
      final off = FakeProvider('off', 'Setup Engine', schedule(), status: const OcrAvailability.setupRequired('Add the model file'));
      final cloud = FakeProvider('cloud', 'Cloud Engine', schedule(), isOnline: true);
      OcrRun? used;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OcrPanel(
                cropPath: 'confirmed_crop.png',
                cropBytes: null,
                registry: OcrRegistry([good, off, cloud], settings: MemorySettings()),
                onUseRun: (run) => used = run,
                onUseCompared: (_) {},
                onReset: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Select OCR Engine', 'Scan with Selected Engine', 'Run All Available Offline Engines', 'Compare Results', 'Reset Results']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      // Open the list: unavailable engines say why.
      await tester.tap(find.text('Select OCR Engine'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Setup required'), findsWidgets);
      expect(find.textContaining('(online)'), findsWidgets);
      await tester.tap(find.text('Good Engine').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan with Selected Engine'));
      await tester.pumpAndSettle();
      expect(good.reads, ['confirmed_crop.png']);
      expect(used?.engineId, 'good');
      expect(cloud.reads, isEmpty);
    });

    testWidgets('without a confirmed crop nothing is read', (tester) async {
      final good = FakeProvider('good', 'Good Engine', schedule());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OcrPanel(
                cropPath: null,
                cropBytes: null,
                registry: OcrRegistry([good], settings: MemorySettings()),
                onUseRun: (_) {},
                onUseCompared: (_) {},
                onReset: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan with Selected Engine'));
      await tester.pumpAndSettle();
      expect(good.reads, isEmpty);
      expect(find.textContaining('confirm the crop'), findsOneWidget);
    });

    testWidgets('the compare screen shows each engine, merges cells with attribution, and keeps corrections', (tester) async {
      tester.view.physicalSize = const Size(1700, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      OcrRun run(String id, String name, String roadKanal) => OcrRun(
        engineId: id,
        engineName: name,
        engineVersion: 'v-$id',
        online: false,
        words: schedule(roadKanal: roadKanal),
        rawText: 'raw $id',
        duration: const Duration(milliseconds: 120),
      );
      OcrCompareResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async => result = await Navigator.push<OcrCompareResult>(
                    context,
                    MaterialPageRoute(builder: (_) => OcrCompareScreen(runs: [run('a', 'Engine A', '18'), run('b', 'Engine B', '13')], cropBytes: null)),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Both engines, with timing and "no confidence" stated, and no winner declared.
      expect(find.text('Engine A'), findsWidgets);
      expect(find.text('Engine B'), findsWidgets);
      expect(find.textContaining('120 ms'), findsWidgets);
      expect(find.textContaining('No confidence reported'), findsWidgets);
      // Taking a cell before choosing a base explains what to do.
      await tester.tap(find.text('Kanal: 13').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Use this result'), findsWidgets);
      // Base = Engine A, then take Engine B's Kanal for row 2.
      await tester.tap(find.text('Use this result').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kanal: 13').last);
      await tester.tap(find.text('Kanal: 13').last);
      await tester.pumpAndSettle();
      expect(find.text('Engine B').evaluate().length, greaterThan(1)); // shown as the cell's source
      await tester.ensureVisible(find.text('Use the working table on the Scan page'));
      await tester.tap(find.text('Use the working table on the Scan page'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.rows[1].kanal, '13');
      expect(result!.sources['2.kanal'], 'b');
      expect(result!.sources['2.marla'], 'a');
      expect(result!.baseEngineId, 'a');
    });
  });
}
