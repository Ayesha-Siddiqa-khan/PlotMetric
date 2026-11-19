import 'package:sqflite/sqflite.dart';

import '../../data/local/app_database.dart';

/// Small key-value store for OCR choices, kept in the app's SQLite database (nothing leaves the device).
class OcrSettings {
  OcrSettings({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  static const preferredEngineKey = 'ocr.preferred_engine';
  static const azureProxyKey = 'ocr.azure_proxy_url';

  /// The saved value, or null when there is none or the database is unavailable.
  Future<String?> read(String key) async {
    try {
      final db = await _database.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      return rows.isEmpty ? null : rows.single['value'] as String;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String? value) async {
    final db = await _database.database;
    if (value == null || value.isEmpty) {
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('app_settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<String?> preferredEngine() => read(preferredEngineKey);
  Future<void> setPreferredEngine(String id) => write(preferredEngineKey, id);
}
