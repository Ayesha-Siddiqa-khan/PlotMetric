import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../data/local/app_database.dart';
import 'scheme.dart';

typedef SchemeListItem = ({int id, String name, String owner, String approval, String updatedAt});

class SchemeRepository {
  SchemeRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<String>> names() async {
    final db = await _database.database;
    final entries = await db.query(
      'scheme_register',
      orderBy: 'name COLLATE NOCASE',
    );
    return entries.map((entry) => entry['name'] as String).toList();
  }

  Future<void> addNames(Iterable<String> names) async {
    final db = await _database.database;
    await db.transaction((txn) => writeNames(txn, names));
  }

  static Future<void> writeNames(
    DatabaseExecutor db,
    Iterable<String> names,
  ) async {
    for (final text in names) {
      final name = text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (name.isEmpty || name.length > 120) continue;
      await db.insert('scheme_register', {
        'name': name,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> removeName(String name) async {
    final db = await _database.database;
    await db.delete('scheme_register', where: 'name = ?', whereArgs: [name]);
  }

  Future<List<SchemeListItem>> list([String search = '']) async {
    final db = await _database.database;
    final query =
        '%${search.trim().toLowerCase().replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_')}%';
    final rows = await db.query(
      'housing_schemes',
      columns: ['id', 'name', 'owner', 'approval', 'updated_at'],
      where:
          "lower(name) LIKE ? ESCAPE '!' OR lower(owner) LIKE ? ESCAPE '!' OR lower(approval) LIKE ? ESCAPE '!'",
      whereArgs: [query, query, query],
      orderBy: 'updated_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => (
            id: row['id'] as int,
            name: row['name'] as String,
            owner: row['owner'] as String,
            approval: row['approval'] as String,
            updatedAt: row['updated_at'] as String,
          ),
        )
        .toList();
  }

  Future<HousingScheme> load(int id) async {
    final db = await _database.database;
    return db.transaction((txn) => _load(txn, id));
  }

  Future<List<HousingScheme>> all() async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final ids = await txn.query(
        'housing_schemes',
        columns: ['id'],
        orderBy: 'id',
      );
      return [for (final row in ids) await _load(txn, row['id'] as int)];
    });
  }

  Future<int> save(HousingScheme scheme) async {
    final db = await _database.database;
    final id = await db.transaction((txn) async {
      final saved = await write(txn, scheme);
      await writeNames(txn, [scheme.name]);
      return saved;
    });
    scheme.id = id;
    return id;
  }

  static Future<HousingScheme> _load(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'housing_schemes',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('This scheme is no longer in Records.');
    final scheme = HousingScheme.fromJson(
      jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>,
      id: id,
    );
    final images = await db.query(
      'scheme_images',
      where: 'scheme_id = ?',
      whereArgs: [id],
    );
    for (final image in images) {
      final slot = image['slot'] as int;
      final data = base64Encode(image['image'] as Uint8List);
      if (slot == -1) {
        scheme.scheduleCrop = data;
      } else {
        scheme.evidence[slot].crop = data;
      }
    }
    return scheme;
  }

  static Future<int> write(DatabaseExecutor db, HousingScheme scheme) async {
    final payload = scheme.toJson()..['crop'] = null;
    for (final document in payload['evidence'] as List<Map<String, dynamic>>) {
      document['crop'] = null;
    }
    final values = {
      'name': scheme.name.trim(),
      'owner': scheme.owner.trim(),
      'approval': scheme.approval.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'payload': jsonEncode(payload),
    };
    final int id;
    if (scheme.id case final existing?) {
      if (await db.update(
            'housing_schemes',
            values,
            where: 'id = ?',
            whereArgs: [existing],
          ) !=
          1) {
        throw StateError('This scheme is no longer in Records.');
      }
      id = existing;
      await db.delete('scheme_images', where: 'scheme_id = ?', whereArgs: [id]);
    } else {
      id = await db.insert('housing_schemes', values);
    }
    final images = [
      scheme.scheduleCrop,
      ...scheme.evidence.map((doc) => doc.crop),
    ];
    for (var i = 0; i < images.length; i++) {
      if (images[i] case final image?) {
        final bytes = base64Decode(image);
        if (bytes.length > 500000) {
          throw const FormatException(
            'A cropped image exceeds the backup size limit.',
          );
        }
        await db.insert('scheme_images', {
          'scheme_id': id,
          'slot': i - 1,
          'image': bytes,
        });
      }
    }
    return id;
  }
}
