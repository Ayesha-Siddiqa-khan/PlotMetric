import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ocr_models.dart';
import '../ocr_provider.dart';
import '../ocr_registry.dart';
import '../ocr_settings.dart';
import '../providers/azure_layout_provider.dart';
import 'ocr_compare_screen.dart';

/// The OCR engine selector for the Scan page. It reads only the confirmed crop file it is given,
/// so every engine sees identical input.
class OcrPanel extends StatefulWidget {
  const OcrPanel({
    super.key,
    required this.cropPath,
    required this.cropBytes,
    required this.onUseRun,
    required this.onUseCompared,
    required this.onReset,
    this.registry,
  });

  /// The confirmed crop as a file; null until the person confirms a crop.
  final String? cropPath;
  final Uint8List? cropBytes;

  /// A single engine finished: show its reconstructed table.
  final void Function(OcrRun run) onUseRun;

  /// The person combined results on the compare screen.
  final void Function(OcrCompareResult result) onUseCompared;
  final VoidCallback onReset;
  final OcrRegistry? registry;

  @override
  State<OcrPanel> createState() => OcrPanelState();
}

class OcrPanelState extends State<OcrPanel> {
  late final OcrRegistry _registry =
      widget.registry ?? OcrRegistry.forThisPlatform();
  List<OcrEngineStatus> _engines = [];
  String? _selected;
  final _runs = <String, OcrRun>{};
  OcrCancelToken? _cancel;
  String? _status;
  bool _loading = true;

  bool get _busy => _cancel != null;

  /// Every result read from the current crop (for provenance).
  List<OcrRun> get runs => _runs.values.toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OcrPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different crop invalidates results read from the old one.
    if (oldWidget.cropPath != widget.cropPath) _runs.clear();
  }

  Future<void> _load() async {
    final engines = await _registry.statuses();
    final preferred = await _registry.preferred();
    if (!mounted) return;
    setState(() {
      _engines = engines;
      _selected =
          preferred?.id ??
          engines.where((e) => e.availability.isReady).firstOrNull?.provider.id;
      _loading = false;
    });
  }

  OcrEngineStatus? get _selectedStatus =>
      _engines.where((e) => e.provider.id == _selected).firstOrNull;

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _askConsent(OcrProvider provider) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Send this crop to ${provider.name}?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This is exactly what will be uploaded:'),
              const SizedBox(height: 8),
              if (widget.cropBytes != null)
                Image.memory(widget.cropBytes!, height: 220),
              const SizedBox(height: 8),
              const Text(
                'The picture leaves this device and is processed online by Microsoft Azure through your backend. '
                'It needs an internet connection, and the service may charge for its use. '
                'Nothing is uploaded unless you agree.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Do not upload'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Upload this crop'),
          ),
        ],
      ),
    );
    return agreed == true;
  }

  Future<OcrRun?> _runOne(OcrProvider provider, OcrCancelToken token) async {
    final path = widget.cropPath!;
    if (provider is AzureLayoutProvider) {
      if (!await _askConsent(provider)) return null;
      provider.grantConsent(path);
    }
    try {
      final run = await provider.recognize(path, cancel: token);
      _runs[provider.id] = run;
      return run;
    } on OcrCancelled {
      return null;
    }
  }

  /// Reads the new crop with the selected engine, but only if that engine is offline:
  /// nothing is ever uploaded without the person asking for it.
  Future<void> autoScan() async {
    final status = _selectedStatus;
    if (status == null ||
        !status.availability.isReady ||
        status.provider.online ||
        _busy) {
      return;
    }
    await _scanSelected();
  }

  Future<void> _scanSelected() async {
    final status = _selectedStatus;
    if (widget.cropPath == null) {
      _toast('Choose an image and confirm the crop first.');
      return;
    }
    if (status == null || !status.availability.isReady) {
      _toast(
        'This engine is not available: ${status?.availability.reason ?? 'none selected'}',
      );
      return;
    }
    final token = OcrCancelToken();
    setState(() {
      _cancel = token;
      _status = 'Reading with ${status.provider.name}…';
    });
    final run = await _runOne(status.provider, token);
    if (!mounted) return;
    setState(() {
      _cancel = null;
      _status = run == null
          ? 'Cancelled.'
          : run.failed
          ? '${status.provider.name} failed: ${run.error}'
          : '${status.provider.name}: ${run.words.length} words in ${run.duration.inMilliseconds} ms.';
    });
    if (run != null && !run.failed) {
      await _registry.settings
          .setPreferredEngine(status.provider.id)
          .catchError((_) {});
      widget.onUseRun(run);
    }
  }

  Future<void> _runAllOffline() async {
    if (widget.cropPath == null) {
      _toast('Choose an image and confirm the crop first.');
      return;
    }
    final token = OcrCancelToken();
    setState(() {
      _cancel = token;
      _status = 'Running every available offline engine on the same crop…';
    });
    await for (final run in _registry.runAllOffline(
      widget.cropPath!,
      cancel: token,
    )) {
      _runs[run.engineId] = run;
      if (mounted) {
        setState(
          () => _status =
              'Finished ${run.engineName} (${run.duration.inMilliseconds} ms).',
        );
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _cancel = null;
      _status = token.isCancelled
          ? 'Cancelled.'
          : '${_runs.length} engine result(s) ready to compare.';
    });
    if (!token.isCancelled && _runs.isNotEmpty) await _compare();
  }

  Future<void> _compare() async {
    final usable = runs;
    if (usable.isEmpty) {
      _toast('Run at least one engine first.');
      return;
    }
    final result = await Navigator.push<OcrCompareResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OcrCompareScreen(runs: usable, cropBytes: widget.cropBytes),
      ),
    );
    if (result != null && mounted) widget.onUseCompared(result);
  }

  void _reset() {
    _cancel?.cancel();
    setState(() {
      _runs.clear();
      _cancel = null;
      _status = 'Results cleared.';
    });
    widget.onReset();
  }

  Future<void> _azureSettings() async {
    final settings = _registry.settings;
    final controller = TextEditingController(
      text: await settings.read(OcrSettings.azureProxyKey) ?? '',
    );
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Azure backend proxy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The app never holds an Azure key. Enter the address of your own backend, which forwards the '
              'crop to Document Intelligence (prebuilt-layout). Leave it empty to keep online OCR off.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Proxy URL (https://…)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final url = controller.text.trim();
      if (url.isNotEmpty && Uri.tryParse(url)?.scheme != 'https') {
        _toast('Use an https:// address.');
      } else {
        await settings.write(OcrSettings.azureProxyKey, url);
        await _load();
      }
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _selectedStatus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OCR engine', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (_loading)
              const LinearProgressIndicator()
            else if (_engines.isEmpty)
              const Text(
                'No OCR engine is available on this platform. Enter the rows by hand.',
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select OCR Engine'),
                  RadioGroup<String>(
                    groupValue: _selected,
                    onChanged: (value) {
                      if (!_busy) {
                        setState(() => _selected = value);
                      }
                    },
                    child: Column(
                      children: [
                        // Every engine is listed; the ones that cannot run say why.
                        for (final engine in _engines)
                          RadioListTile<String>(
                            dense: true,
                            value: engine.provider.id,
                            enabled: engine.availability.isReady && !_busy,
                            title: Text(
                              '${engine.provider.name}${engine.provider.online ? ' (online)' : ''}'
                              '${engine.availability.isReady
                                  ? ''
                                  : engine.availability.status == OcrStatus.unsupported
                                  ? ' — Disabled'
                                  : ' — Setup required'}',
                            ),
                            subtitle: Text(engine.availability.reason),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            if (status != null) ...[
              const SizedBox(height: 4),
              Text(
                '${status.provider.version}. ${status.availability.reason}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy || _loading ? null : _scanSelected,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan with Selected Engine'),
                ),
                OutlinedButton(
                  onPressed: _busy || _loading ? null : _runAllOffline,
                  child: const Text('Run All Available Offline Engines'),
                ),
                OutlinedButton(
                  onPressed: _busy || _runs.isEmpty ? null : _compare,
                  child: const Text('Compare Results'),
                ),
                OutlinedButton(
                  onPressed: _runs.isEmpty && !_busy ? null : _reset,
                  child: const Text('Reset Results'),
                ),
                if (_busy)
                  OutlinedButton(
                    onPressed: () => _cancel?.cancel(),
                    child: const Text('Cancel Processing'),
                  ),
                TextButton(
                  onPressed: _busy ? null : _azureSettings,
                  child: const Text('Online OCR setup'),
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_status!),
              ),
          ],
        ),
      ),
    );
  }
}
