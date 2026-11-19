import 'package:sqflite/sqflite.dart';

import '../../../data/local/app_database.dart';
import 'approved_land.dart';
import 'approved_land_seed.dart';

class ApprovedLandRepository {
  ApprovedLandRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  static const _seededKey = 'seeded';

  /// Loads the register, filling it once from the printed sheet on first use.
  Future<List<ApprovedLandEntry>> all() async {
    final db = await _database.database;
    await db.transaction((txn) => seedIfNeeded(txn));
    final rows = await db.query(
      'approved_land',
      orderBy: 'serial IS NULL, serial, id',
    );
    return rows.map(ApprovedLandEntry.fromDb).toList();
  }

  /// Inserts the printed register exactly once; later edits or deletions are never undone.
  static Future<void> seedIfNeeded(DatabaseExecutor db) async {
    final flag = await db.query(
      'approved_land_meta',
      where: 'key = ?',
      whereArgs: [_seededKey],
    );
    if (flag.isNotEmpty) return;
    for (final row in approvedLandSeed) {
      await db.insert(
        'approved_land',
        ApprovedLandEntry(
          serial: row.serial,
          name: row.name,
          owner: row.owner,
          mouza: row.mouza,
          totalArea: LandAreaText.normalize(row.total),
          transferred: LandAreaText.normalize(row.transferred),
          remaining: LandAreaText.normalize(row.remaining),
          mortgage: LandAreaText.normalize(row.mortgage),
          note: row.note,
        ).toDb(),
      );
    }
    await markSeeded(db);
  }

  static Future<void> markSeeded(DatabaseExecutor db) => db.insert(
    'approved_land_meta',
    {'key': _seededKey, 'value': '1'},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<ApprovedLandEntry?> byId(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'approved_land',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : ApprovedLandEntry.fromDb(rows.single);
  }

  /// Case-insensitive match on the scheme name, used when a scan is saved from the Scan tab.
  Future<ApprovedLandEntry?> byName(String name) async {
    final db = await _database.database;
    final rows = await db.query(
      'approved_land',
      where: 'lower(trim(name)) = ?',
      whereArgs: [name.trim().toLowerCase()],
      orderBy: 'serial IS NULL, serial, id',
      limit: 1,
    );
    return rows.isEmpty ? null : ApprovedLandEntry.fromDb(rows.first);
  }

  Future<int> save(ApprovedLandEntry entry) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      if (entry.id case final id?) {
        await txn.update(
          'approved_land',
          entry.toDb(),
          where: 'id = ?',
          whereArgs: [id],
        );
        return id;
      }
      if (entry.serial == null) {
        final max = await txn.rawQuery(
          'SELECT MAX(serial) AS value FROM approved_land',
        );
        entry.serial = ((max.first['value'] as int?) ?? 0) + 1;
      }
      final id = await txn.insert('approved_land', entry.toDb());
      entry.id = id;
      return id;
    });
  }

  Future<void> delete(int id) async {
    final db = await _database.database;
    await db.delete('approved_land', where: 'id = ?', whereArgs: [id]);
  }

  /// Records the outcome of a saved scan on its register row.
  Future<void> applyScan(
    int id, {
    required int schemeId,
    int? transferArea,
    String transferred = '',
    String totalAreaIfEmpty = '',
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'approved_land',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return;
      final entry = ApprovedLandEntry.fromDb(rows.single)..schemeId = schemeId;
      // With no ticked rows there is no transfer figure yet; keep what the register already holds.
      if (transferArea != null) {
        entry.transferTotal = LandAreaText.format(transferArea);
        // Nothing typed this time: keep the transferred figure already on record.
        if (transferred.trim().isNotEmpty) {
          entry.transferred = LandAreaText.normalize(transferred); }
        entry.remaining = ApprovedLandEntry.computeRemaining(
          entry.transferTotal,
          entry.transferred,
        );
      }
      if (entry.totalArea.trim().isEmpty && totalAreaIfEmpty.isNotEmpty) {
        entry.totalArea = totalAreaIfEmpty;
      }
      await txn.update(
        'approved_land',
        entry.toDb(),
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
