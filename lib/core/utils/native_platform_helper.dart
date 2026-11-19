import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativePlatformHelper {
  static const MethodChannel _channel = MethodChannel('com.plotmetric.plotmetric/native');

  static Future<String> recognizeImageText(String filePath) async {
    return await _channel.invokeMethod<String>('recognizeImageText', {
      'filePath': filePath,
    }) ?? '';
  }

  /// True where table text recognition works offline (Android ML Kit, Windows OCR).
  static bool get canRecognizeTable =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  static Future<List<Object?>> recognizeImageTable(String filePath) async {
    if (!kIsWeb && Platform.isWindows) return _recognizeWindowsTable(filePath);
    return await _channel.invokeListMethod<Object?>('recognizeImageTable', {'filePath': filePath}) ?? [];
  }

  // Uses the Windows built-in OCR engine (offline, no downloads).
  static const _windowsOcrScript = r'''
param([string]$Path)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Drawing
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Storage.StorageFile, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Foundation, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
  $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($operation, $type) {
  $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
  $task.Wait(-1) | Out-Null
  $task.Result
}
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
if ($null -eq $engine) { throw 'No Windows OCR language is installed.' }
$source = [System.Drawing.Image]::FromFile($Path)

# Enlarge and convert to high-contrast grey (green channel) so coloured ink reads well.
function Prepare($targetWidth, $contrast, $destination) {
  $scale = [Math]::Min([Math]::Max($targetWidth / $source.Width, 1.0), 6.0)
  $width = [int]($source.Width * $scale)
  $height = [int]($source.Height * $scale)
  $canvas = New-Object System.Drawing.Bitmap $width, $height
  $graphics = [System.Drawing.Graphics]::FromImage($canvas)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $rectangle = New-Object System.Drawing.Rectangle 0, 0, $width, $height
  if ($contrast -le 0) {
    # Untouched colours: low-contrast grey photos are read best as they are.
    $graphics.DrawImage($source, $rectangle, 0, 0, $source.Width, $source.Height, [System.Drawing.GraphicsUnit]::Pixel)
  } else {
    $matrix = New-Object 'single[][]' 5
    for ($i = 0; $i -lt 5; $i++) { $matrix[$i] = New-Object 'single[]' 5 }
    foreach ($column in 0..2) {
      $matrix[1][$column] = [single]$contrast
      $matrix[4][$column] = [single](-0.45 * $contrast)
    }
    $matrix[3][3] = 1
    $matrix[4][3] = 1
    $attributes = New-Object System.Drawing.Imaging.ImageAttributes
    $attributes.SetColorMatrix((New-Object System.Drawing.Imaging.ColorMatrix(, $matrix)))
    $graphics.DrawImage($source, $rectangle, 0, 0, $source.Width, $source.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
  }
  $graphics.Dispose()
  $canvas.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
  $canvas.Dispose()
  return $scale
}

function Recognize($file) {
  $storage = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($file)) ([Windows.Storage.StorageFile])
  $stream = Await ($storage.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
}

# Each pass misses different cells, so read the picture several ways and merge.
$words = New-Object System.Collections.ArrayList
$passes = @(@(4000, 2.2), @(2400, 3.0), @(2400, 2.2), @(1600, 1.0), @(2400, 0), @(3600, 0))
foreach ($pass in $passes) {
  $Prepared = Join-Path $PSScriptRoot 'prepared.png'
  $scale = Prepare $pass[0] $pass[1] $Prepared
  $result = Recognize $Prepared
  # A tilted photo makes text lines slope; measure the slope and level the rows.
  $sumX = 0.0; $sumY = 0.0
  foreach ($line in $result.Lines) {
    if ($line.Words.Count -lt 2) { continue }
    $first = $line.Words[0].BoundingRect
    $last = $line.Words[$line.Words.Count - 1].BoundingRect
    $dx = ($last.X + $last.Width / 2) - ($first.X + $first.Width / 2)
    if ($dx -gt 0) { $sumX += $dx; $sumY += ($last.Y + $last.Height / 2) - ($first.Y + $first.Height / 2) }
  }
  $slope = if ($sumX -gt 0) { $sumY / $sumX } else { 0.0 }
  foreach ($line in $result.Lines) {
    foreach ($word in $line.Words) {
      $r = $word.BoundingRect
      $x = ($r.X + $r.Width / 2) / $scale
      $y = (($r.Y + $r.Height / 2) - $slope * ($r.X + $r.Width / 2)) / $scale
      $h = $r.Height / $scale
      $w = $r.Width / $scale
      $known = $false
      foreach ($other in $words) {
        if ([Math]::Abs($other.x - $x) -lt [Math]::Max($w, $other.width) * 0.5 -and
            [Math]::Abs($other.y - $y) -lt [Math]::Max($h, $other.height) * 0.5) { $known = $true; break }
      }
      if (-not $known) {
        [void]$words.Add([pscustomobject]@{ text = $word.Text; x = [double]$x; y = [double]$y; height = [double]$h; width = [double]$w })
      }
    }
  }
}
$source.Dispose()
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::Write((ConvertTo-Json -InputObject @($words) -Compress))
''';

  static Future<List<Object?>> _recognizeWindowsTable(String filePath) async {
    final directory = await Directory.systemTemp.createTemp('plotmetric_ocr_');
    try {
      final script = await File('${directory.path}${Platform.pathSeparator}ocr.ps1')
          .writeAsString('﻿$_windowsOcrScript');
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script.path, '-Path', filePath],
        stdoutEncoding: utf8,
      );
      if (result.exitCode != 0) throw StateError('Windows OCR failed.');
      final text = result.stdout.toString().trim();
      if (text.isEmpty) return [];
      final decoded = jsonDecode(text);
      return decoded is List ? List<Object?>.from(decoded) : [decoded];
    } finally {
      await directory.delete(recursive: true);
    }
  }

  static Future<({String reference, String path, String name})> saveAndroidExport(
    String fileName,
    Uint8List bytes,
  ) async {
    final saved = await _channel.invokeMapMethod<String, String>('saveExport', {
      'fileName': fileName,
      'mimeType': _detectMimeType(fileName),
      'bytes': bytes,
    });
    if (saved == null) throw StateError('Android did not return a saved file.');
    return (reference: saved['reference']!, path: saved['path']!, name: saved['name']!);
  }

  /// Shares plain text message using native Android share sheet (WhatsApp, Gmail, Drive, etc.)
  static Future<bool> shareText(String text, {String title = 'Share via'}) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('shareText', {
          'text': text,
          'title': title,
        });
        return res ?? true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Shares a file attachment using native Android share sheet (WhatsApp, Gmail, Drive, etc.)
  static Future<bool> shareFile(String filePath, {String? mimeType, String title = 'Share File', bool preferWhatsApp = false}) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final effectiveMime = mimeType ?? _detectMimeType(filePath);
        final res = await _channel.invokeMethod<bool>('shareFile', {
          'filePath': filePath,
          'mimeType': effectiveMime,
          'title': title,
          'preferWhatsApp': preferWhatsApp,
        });
        return res ?? true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Opens a file in the host OS default viewer (e.g. PDF viewer, Excel, Word, Notepad)
  static Future<bool> openFile(String filePath, {String? mimeType}) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final effectiveMime = mimeType ?? _detectMimeType(filePath);
        final res = await _channel.invokeMethod<bool>('openFile', {
          'filePath': filePath,
          'mimeType': effectiveMime,
        });
        return res ?? true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '""', filePath], runInShell: true);
        return true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', [filePath]);
        return true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [filePath]);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Opens folder in explorer or reveals file in file manager
  static Future<bool> openFolder(String filePath) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('openFolder', {
          'filePath': filePath,
        });
        return res ?? true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', filePath]);
        return true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', ['-R', filePath]);
        return true;
      } catch (_) {
        return false;
      }
    } else if (Platform.isLinux) {
      try {
        final parentDir = File(filePath).parent.path;
        await Process.run('xdg-open', [parentDir]);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Picks an image or document from gallery/storage
  static Future<String?> pickImage({bool csvOnly = false}) async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('pickImage', {'csvOnly': csvOnly});
        return path;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Captures photo via camera and returns the local file path
  static Future<String?> takePhoto() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('takePhoto');
        return path;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _detectMimeType(String filePath) {
    if (filePath.startsWith('content://')) return '*/*';
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'csv':
        return 'text/csv';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'json':
        return 'application/json';
      case 'txt':
        return 'text/plain';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return '*/*';
    }
  }
}
