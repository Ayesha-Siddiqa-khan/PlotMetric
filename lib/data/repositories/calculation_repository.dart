import 'package:sqflite/sqflite.dart';
import '../local/app_database.dart';
import '../models/calculation.dart';
import '../models/measurement_entry.dart';
import '../../core/constants/land_units.dart';

class CalculationRepository {
  final AppDatabase _dbProvider;

  CalculationRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<Database> get _db => _dbProvider.database;

  /// Retrieves all saved calculations, optionally filtered by title query (case-insensitive)
  Future<List<Calculation>> getAllCalculations({String? query}) async {
    final db = await _db;

    List<Map<String, dynamic>> rows;
    if (query != null && query.trim().isNotEmpty) {
      final sanitizedQuery = '%${query.trim()}%';
      rows = await db.rawQuery('''
        SELECT * FROM calculations
        WHERE LOWER(title) LIKE LOWER(?)
        ORDER BY updated_at_utc DESC
      ''', [sanitizedQuery]);
    } else {
      rows = await db.query(
        'calculations',
        orderBy: 'updated_at_utc DESC',
      );
    }

    final calculations = <Calculation>[];
    for (final row in rows) {
      final calculationId = row['id'] as int;
      final entryRows = await db.query(
        'measurement_entries',
        where: 'calculation_id = ?',
        whereArgs: [calculationId],
        orderBy: 'sort_order ASC',
      );
      final entries = entryRows.map((e) => MeasurementEntry.fromMap(e)).toList();
      calculations.add(Calculation.fromMap(row, entries: entries));
    }

    return calculations;
  }

  /// Retrieves a specific calculation by ID with its ordered entries
  Future<Calculation?> getCalculationById(int id) async {
    final db = await _db;
    final calcRows = await db.query(
      'calculations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (calcRows.isEmpty) return null;

    final entryRows = await db.query(
      'measurement_entries',
      where: 'calculation_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order ASC',
    );

    final entries = entryRows.map((e) => MeasurementEntry.fromMap(e)).toList();
    return Calculation.fromMap(calcRows.first, entries: entries);
  }

  /// Inserts a new calculation and all its entries in an atomic transaction
  Future<int> insertCalculation(Calculation calculation) async {
    final db = await _db;
    return await db.transaction<int>((txn) async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final calcMap = calculation.toMap();
      calcMap['created_at_utc'] = calculation.createdAtUtc.isNotEmpty
          ? calculation.createdAtUtc
          : nowUtc;
      calcMap['updated_at_utc'] = nowUtc;

      final calcId = await txn.insert('calculations', calcMap);

      for (int i = 0; i < calculation.entries.length; i++) {
        final entry = calculation.entries[i];
        final entryMap = entry.toMap(overrideCalculationId: calcId);
        entryMap['sort_order'] = i;
        await txn.insert('measurement_entries', entryMap);
      }

      return calcId;
    });
  }

  /// Updates an existing calculation and replaces its line items atomically
  Future<void> updateCalculation(Calculation calculation) async {
    final db = await _db;
    final calcId = calculation.id;
    if (calcId == null) {
      throw ArgumentError('Cannot update calculation without an id');
    }

    await db.transaction((txn) async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final calcMap = calculation.toMap();
      calcMap['updated_at_utc'] = nowUtc;

      await txn.update(
        'calculations',
        calcMap,
        where: 'id = ?',
        whereArgs: [calcId],
      );

      // Replace existing entries with updated entries
      await txn.delete(
        'measurement_entries',
        where: 'calculation_id = ?',
        whereArgs: [calcId],
      );

      for (int i = 0; i < calculation.entries.length; i++) {
        final entry = calculation.entries[i];
        final entryMap = entry.toMap(overrideCalculationId: calcId);
        entryMap['sort_order'] = i;
        await txn.insert('measurement_entries', entryMap);
      }
    });
  }

  /// Deletes a calculation and cascades to its entries
  Future<void> deleteCalculation(int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'measurement_entries',
        where: 'calculation_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'calculations',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Fetches unique historical purposes used in SQLite and merges with defaults
  Future<List<String>> getDistinctPurposes() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT DISTINCT purpose FROM measurement_entries
      WHERE purpose IS NOT NULL AND TRIM(purpose) != ''
    ''');

    final seen = <String>{};
    final result = <String>[];

    // Add defaults first
    for (final p in LandUnits.defaultPurposes) {
      final lower = p.trim().toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        result.add(p);
      }
    }

    // Add historical user purposes
    for (final row in rows) {
      final p = (row['purpose'] as String?)?.trim();
      if (p != null && p.isNotEmpty) {
        final lower = p.toLowerCase();
        if (!seen.contains(lower)) {
          seen.add(lower);
          result.add(p);
        }
      }
    }

    return result;
  }
}
