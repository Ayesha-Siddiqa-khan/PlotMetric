import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/native_platform_helper.dart';
import '../../export/logic/file_save_helper.dart';
import '../logic/scheme_register_csv.dart';
import '../logic/scheme_repository.dart';
import 'crop_image_screen.dart';
import 'scheme_editors.dart';

class SchemeRegister extends StatefulWidget {
  const SchemeRegister({super.key});

  static Future<void> open(BuildContext context) => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => const SchemeRegister()),
  );

  @override
  State<SchemeRegister> createState() => _SchemeRegisterState();
}

class _SchemeRegisterState extends State<SchemeRegister> {
  final _repo = SchemeRepository();
  late Future<List<String>> _names = _repo.names();
  String _search = '';
  bool _busy = false;

  void _refresh() => setState(() => _names = _repo.names());

  Future<void> _paste({String initial = ''}) async {
    var lines = initial;
    final submitted = await schemeDialog<String>(
      context,
      'Review register names',
      (dialog) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter one scheme name per line. You can paste the entire name column from Excel.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: initial,
            onChanged: (value) => lines = value,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Scheme names'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, lines),
            child: const Text('Add to register'),
          ),
        ],
      ),
    );
    if (submitted == null || !mounted) return;
    try {
      await _repo.addNames(
        submitted
            .split(RegExp(r'[\r\n]+'))
            .map((line) => line.trim())
            .where(
              (name) =>
                  name.isNotEmpty &&
                  !RegExp(
                    r'^name of (?:housing|house) scheme$',
                    caseSensitive: false,
                  ).hasMatch(name),
            ),
      );
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) _error('Could not save the register names.');
    }
  }

  void _error(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _importCsv() async {
    setState(() => _busy = true);
    try {
      final String? path;
      if (Platform.isAndroid) {
        path = await NativePlatformHelper.pickImage(csvOnly: true);
      } else {
        final selected = await Process.run('powershell', [
          '-NoProfile', '-STA', '-Command', r'''
Add-Type -AssemblyName System.Windows.Forms
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$picker = New-Object System.Windows.Forms.OpenFileDialog
$picker.Filter = 'CSV files (*.csv)|*.csv'
if ($picker.ShowDialog() -eq 'OK') { [Console]::Write($picker.FileName) }
''',
        ], stdoutEncoding: utf8);
        path = selected.exitCode == 0 ? selected.stdout.toString().trim() : null;
      }
      if (path == null || path.isEmpty || !mounted) return;
      final file = File(path);
      if (await file.length() > 4000000) {
        throw const FormatException('The register CSV is too large.');
      }
      final names = SchemeRegisterCsv.readNames(await file.readAsString());
      if (mounted) await _paste(initial: names.join('\n'));
    } on FormatException catch (error) {
      if (mounted) _error(error.message);
    } catch (_) {
      if (mounted) _error('Could not read the file. Save the register as CSV UTF-8 in Excel.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final csv = SchemeRegisterCsv.export(await _repo.names(), await _repo.all());
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final result = await FileSaveHelper.saveTextFile(
        fileName: 'PlotMetric_Office_Register_$timestamp.csv', content: csv,
      );
      if (!mounted) return;
      if (!result.success) {
        _error(result.errorMessage ?? 'Could not save the register CSV.');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved ${result.fileName}'),
        action: SnackBarAction(label: 'Open', onPressed: () async {
          final opened = await FileSaveHelper.openFile(result.filePath);
          if (mounted && !opened) _error('Open the register CSV from your exports folder.');
        }),
      ));
    } catch (_) {
      if (mounted) _error('Could not export the office register.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan(bool camera) async {
    setState(() => _busy = true);
    try {
      final crop = await CropImageScreen.pick(context, camera: camera);
      if (crop == null || !mounted) return;
      final names = await CropImageScreen.withScanFile(
        crop.scan,
        NativePlatformHelper.recognizeImageText,
      );
      if (mounted) await _paste(initial: names);
    } catch (_) {
      if (mounted) {
        _error(
          'Could not read the register photo. Try another crop or paste the names.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove register name?'),
        content: Text(name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.removeName(name);
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) _error('Could not remove the register name.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Office scheme register')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by scheme name',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (Platform.isAndroid || Platform.isWindows)
                      OutlinedButton(onPressed: _busy ? null : _importCsv, child: const Text('Import CSV')),
                    FilledButton(onPressed: _busy ? null : _exportCsv, child: const Text('Export register CSV')),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _paste(),
                      child: const Text('Type or paste names'),
                    ),
                    if (Platform.isAndroid) ...[
                      OutlinedButton(
                        onPressed: _busy ? null : () => _scan(false),
                        child: const Text('Choose register photo'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _scan(true),
                        child: const Text('Photograph register'),
                      ),
                    ],
                  ],
                ),
                if (Platform.isAndroid)
                  const Text(
                    'For a photo, rotate if needed and crop only the Name of Housing Scheme column.',
                  ),
                if (_busy) const LinearProgressIndicator(),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _names,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load the scheme register.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final matching = snapshot.data!
                    .where((name) => name.toLowerCase().contains(_search))
                    .toList();
                if (matching.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching names. Add names or type one in the worksheet.',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: matching.length,
                  itemBuilder: (context, index) {
                    final name = matching[index];
                    return ListTile(
                      title: Text(name),
                      trailing: IconButton(
                        tooltip: 'Remove name',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _remove(name),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
