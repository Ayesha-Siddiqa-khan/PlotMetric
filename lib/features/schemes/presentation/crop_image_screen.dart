import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/utils/native_platform_helper.dart';
import '../../ocr/image_adjust.dart';

/// The confirmed crop. The original file, the crop rectangle (fractions of the rotated picture),
/// the number of quarter turns and the adjustments are kept so the scan can be explained later.
typedef CropResult = ({
  Uint8List scan,
  Uint8List preview,
  String originalPath,
  List<double> cropRect,
  int rotationTurns,
  Map<String, Object> adjustments,
});

class CropImageScreen extends StatefulWidget {
  const CropImageScreen({super.key, required this.path});
  final String path;

  static Future<CropResult?> open(BuildContext context, String path) =>
      Navigator.push<CropResult>(
        context,
        MaterialPageRoute(builder: (_) => CropImageScreen(path: path)),
      );

  static Future<CropResult?> pick(
    BuildContext context, {
    bool camera = false,
  }) async {
    final String? path;
    if (Platform.isAndroid) {
      path = await (camera
          ? NativePlatformHelper.takePhoto()
          : NativePlatformHelper.pickImage());
    } else if (Platform.isWindows) {
      if (camera) {
        // Windows has no in-app camera: open the Camera app, then pick the saved photo.
        await Process.run('cmd', ['/c', 'start', '', 'microsoft.windows.camera:'], runInShell: true);
        if (!context.mounted) return null;
        final ready = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Windows Camera opened'),
            content: const Text(
              'Take the photo of the area schedule in the Camera app, then come back and press "Choose captured photo".',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Choose captured photo')),
            ],
          ),
        );
        if (ready != true) return null;
      }
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-STA',
        '-Command',
        r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$camera = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Camera Roll'
if ('CAMERA' -eq '1' -and (Test-Path $camera)) { $dialog.InitialDirectory = $camera }
$dialog.Filter = 'Images (*.jpg;*.jpeg;*.png;*.bmp)|*.jpg;*.jpeg;*.png;*.bmp'
if ($dialog.ShowDialog() -eq 'OK') { [Console]::Write($dialog.FileName) }
'''.replaceAll("'CAMERA'", camera ? "'1'" : "'0'"),
      ]);
      path = result.exitCode == 0 ? result.stdout.toString().trim() : null;
    } else {
      path = null;
    }
    return path == null || path.isEmpty || !context.mounted
        ? null
        : open(context, path);
  }

  static Future<T> withScanFile<T>(
    Uint8List bytes,
    Future<T> Function(String) scan,
  ) async {
    final directory = await Directory.systemTemp.createTemp('plotmetric_crop_');
    try {
      final file = await File(
        '${directory.path}${Platform.pathSeparator}scan.png',
      ).writeAsBytes(bytes);
      return await scan(file.path);
    } finally {
      await directory.delete(recursive: true);
    }
  }

  @override
  State<CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends State<CropImageScreen> {
  final _zoom = TransformationController();
  ui.Image? _image;
  String? _error;
  bool _working = false;
  Rect _crop = const Rect.fromLTRB(0.08, 0.08, 0.92, 0.92);
  int _turns = 0;
  ImageAdjustments _adjust = const ImageAdjustments();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        await File(widget.path).readAsBytes(),
      );
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          return width >= height
              ? ui.TargetImageSize(width: math.min(4096, width))
              : ui.TargetImageSize(height: math.min(4096, height));
        },
      );
      try {
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        setState(() => _image = frame.image);
      } finally {
        codec.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This file could not be opened as an image.');
      }
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _zoom.dispose();
    super.dispose();
  }

  Future<void> _rotate() async {
    final source = _image;
    if (source == null) return;
    setState(() => _working = true);
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..translate(source.height.toDouble(), 0)
      ..rotate(math.pi / 2)
      ..drawImage(source, Offset.zero, Paint());
    final picture = recorder.endRecording();
    try {
      final rotated = await picture.toImage(source.height, source.width);
      if (!mounted) {
        rotated.dispose();
        return;
      }
      source.dispose();
      _zoom.value = Matrix4.identity();
      setState(() {
        _turns = (_turns + 1) % 4;
        _image = rotated;
        _crop = Rect.fromLTRB(
          1 - _crop.bottom,
          _crop.left,
          1 - _crop.top,
          _crop.right,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not rotate the image.');
    } finally {
      picture.dispose();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<Uint8List> _render(ui.Image image, Rect bounds, double scale) async {
    final width = math.max(1, (bounds.width * scale).round());
    final height = math.max(1, (bounds.height * scale).round());
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      bounds,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = _adjust.needsColorFilter ? ColorFilter.matrix(_adjust.colorMatrix()) : null,
    );
    final picture = recorder.endRecording();
    try {
      final output = await picture.toImage(width, height);
      try {
        if (_adjust.sharpen) {
          final raw = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
          if (raw == null) throw StateError('Could not read the crop.');
          final sharpened = sharpenRgba(raw.buffer.asUint8List(), width, height);
          final done = Completer<ui.Image>();
          ui.decodeImageFromPixels(sharpened, width, height, ui.PixelFormat.rgba8888, done.complete);
          final sharp = await done.future;
          try {
            final data = await sharp.toByteData(format: ui.ImageByteFormat.png);
            if (data == null) throw StateError('Could not encode the crop.');
            return data.buffer.asUint8List();
          } finally {
            sharp.dispose();
          }
        }
        final data = await output.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('Could not encode the crop.');
        return data.buffer.asUint8List();
      } finally {
        output.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  Future<void> _confirm() async {
    final image = _image;
    if (image == null) return;
    setState(() => _working = true);
    try {
      final rect = Rect.fromLTRB(
        _crop.left * image.width,
        _crop.top * image.height,
        _crop.right * image.width,
        _crop.bottom * image.height,
      );
      final scanScale = (1300 / rect.longestSide).clamp(1.0, 2.0);
      final scan = await _render(image, rect, scanScale);
      var scale = math.min(1.0, 1400 / rect.longestSide);
      var preview = scan.length <= 450000 && scale == scanScale
          ? scan
          : await _render(image, rect, scale);
      while (preview.length > 450000) {
        scale *= 0.75;
        preview = await _render(image, rect, scale);
      }
      if (mounted) {
        Navigator.pop(context, (
          scan: scan,
          preview: preview,
          originalPath: widget.path,
          cropRect: [_crop.left, _crop.top, _crop.right, _crop.bottom],
          rotationTurns: _turns,
          adjustments: _adjust.toJson(),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not crop the image.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _resize(int corner, Offset delta, Size size) {
    final left = corner == 0 || corner == 2;
    final top = corner < 2;
    final x = delta.dx / size.width;
    final y = delta.dy / size.height;
    setState(
      () => _crop = Rect.fromLTRB(
        left ? (_crop.left + x).clamp(0, _crop.right - 0.025) : _crop.left,
        top ? (_crop.top + y).clamp(0, _crop.bottom - 0.025) : _crop.top,
        left ? _crop.right : (_crop.right + x).clamp(_crop.left + 0.025, 1),
        top ? _crop.bottom : (_crop.bottom + y).clamp(_crop.top + 0.025, 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop document'),
        actions: [
          IconButton(
            tooltip: 'Rotate clockwise',
            onPressed: _working || image == null ? null : _rotate,
            icon: const Icon(Icons.rotate_right),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Drag the four corners around the table. Pinch to zoom.',
              ),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
            Expanded(
              child: image == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : null,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final scale = math.min(
                          constraints.maxWidth / image.width,
                          constraints.maxHeight / image.height,
                        );
                        final size = Size(
                          image.width * scale,
                          image.height * scale,
                        );
                        final rect = Rect.fromLTRB(
                          _crop.left * size.width,
                          _crop.top * size.height,
                          _crop.right * size.width,
                          _crop.bottom * size.height,
                        );
                        final corners = [
                          rect.topLeft,
                          rect.topRight,
                          rect.bottomLeft,
                          rect.bottomRight,
                        ];
                        return InteractiveViewer(
                          transformationController: _zoom,
                          maxScale: 6,
                          child: Center(
                            child: SizedBox.fromSize(
                              size: size,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: _adjust.needsColorFilter
                                        ? ColorFiltered(
                                            colorFilter: ColorFilter.matrix(_adjust.colorMatrix()),
                                            child: RawImage(image: image, fit: BoxFit.fill),
                                          )
                                        : RawImage(image: image, fit: BoxFit.fill),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _CropOverlay(rect),
                                      ),
                                    ),
                                  ),
                                  for (final (index, corner) in corners.indexed)
                                    Positioned(
                                      left: corner.dx - 20,
                                      top: corner.dy - 20,
                                      width: 40,
                                      height: 40,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanUpdate: _working
                                            ? null
                                            : (drag) => _resize(
                                                index,
                                                drag.delta,
                                                size,
                                              ),
                                        child: const Center(
                                          child: CircleAvatar(
                                            radius: 9,
                                            backgroundColor: Colors.tealAccent,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            ExpansionTile(
              title: const Text('Adjust image (brightness, contrast, grayscale, sharpen)'),
              children: [
                Row(
                  children: [
                    const SizedBox(width: 16),
                    const Text('Brightness'),
                    Expanded(
                      child: Slider(
                        value: _adjust.brightness,
                        min: -0.5,
                        max: 0.5,
                        onChanged: _working
                            ? null
                            : (value) => setState(
                                () => _adjust = ImageAdjustments(
                                  brightness: value,
                                  contrast: _adjust.contrast,
                                  grayscale: _adjust.grayscale,
                                  sharpen: _adjust.sharpen,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    const Text('Contrast'),
                    Expanded(
                      child: Slider(
                        value: _adjust.contrast,
                        min: 0.5,
                        max: 2,
                        onChanged: _working
                            ? null
                            : (value) => setState(
                                () => _adjust = ImageAdjustments(
                                  brightness: _adjust.brightness,
                                  contrast: value,
                                  grayscale: _adjust.grayscale,
                                  sharpen: _adjust.sharpen,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Grayscale'),
                  value: _adjust.grayscale,
                  onChanged: _working
                      ? null
                      : (value) => setState(
                          () => _adjust = ImageAdjustments(
                            brightness: _adjust.brightness,
                            contrast: _adjust.contrast,
                            grayscale: value,
                            sharpen: _adjust.sharpen,
                          ),
                        ),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Sharpen (applied to the final crop)'),
                  value: _adjust.sharpen,
                  onChanged: _working
                      ? null
                      : (value) => setState(
                          () => _adjust = ImageAdjustments(
                            brightness: _adjust.brightness,
                            contrast: _adjust.contrast,
                            grayscale: _adjust.grayscale,
                            sharpen: value,
                          ),
                        ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: _working ? null : () => Navigator.pop(context),
                    child: const Text('Retake / Choose another'),
                  ),
                  FilledButton.icon(
                    onPressed: _working || image == null ? null : _confirm,
                    icon: const Icon(Icons.crop),
                    label: Text(_working ? 'Processing…' : 'Use crop'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropOverlay extends CustomPainter {
  _CropOverlay(this.rect);
  final Rect rect;
  @override
  void paint(Canvas canvas, Size size) {
    final mask = Path()..fillType = PathFillType.evenOdd;
    mask.addRect(Offset.zero & size);
    mask.addRect(rect);
    canvas.drawPath(mask, Paint()..color = Colors.black45);
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.tealAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropOverlay previous) => previous.rect != rect;
}
