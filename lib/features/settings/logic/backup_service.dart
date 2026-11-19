import 'dart:convert';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/calculation_repository.dart';

class BackupRestoreResult {
  final bool success;
  final int calculationsCount;
  final int entriesCount;
  final String? errorMessage;

  const BackupRestoreResult({
    required this.success,
    this.calculationsCount = 0,
    this.entriesCount = 0,
    this.errorMessage,
  });
}

class BackupService {
  final CalculationRepository _repository;
  final AppDatabase _dbProvider;

  BackupService({
    CalculationRepository? repository,
    AppDatabase? dbProvider,
  })  : _repository = repository ?? CalculationRepository(),
        _dbProvider = dbProvider ?? AppDatabase.instance;

  /// Serializes all calculations and entries to a structured JSON string
  Future<String> exportBackupJson() async {
    final calculations = await _repository.getAllCalculations();

    final backupMap = {
      'app': 'PlotMetric',
      'format_version': 1,
      'exported_at_utc': DateTime.now().toUtc().toIso8601String(),
      'total_calculations': calculations.length,
      'calculations': calculations.map((calc) {
        return {
          'title': calc.title,
          'calculation_date': calc.calculationDate,
          'calculation_time': calc.calculationTime,
          'created_at_utc': calc.createdAtUtc,
          'updated_at_utc': calc.updatedAtUtc,
          'entries': calc.entries.map((e) {
            return {
              'sort_order': e.sortOrder,
              'purpose': e.purpose,
              'operation': e.operation.dbValue,
              'kanal': e.kanal,
              'marla': e.marla,
              'sarsai_centi': e.sarsaiCenti,
            };
          }).toList(),
        };
      }).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(backupMap);
  }

  /// Restores calculations and entries from a JSON backup string into SQLite
  Future<BackupRestoreResult> restoreFromJson(String jsonString, {bool replaceAll = false}) async {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const BackupRestoreResult(
          success: false,
          errorMessage: 'Invalid backup file format: Root must be a JSON object.',
        );
      }

      if (decoded['app'] != 'PlotMetric') {
        return const BackupRestoreResult(
          success: false,
          errorMessage: 'Unrecognized backup file: Missing PlotMetric header.',
        );
      }

      final rawCalculations = decoded['calculations'];
      if (rawCalculations is! List) {
        return const BackupRestoreResult(
          success: false,
          errorMessage: 'Invalid calculations array in backup file.',
        );
      }

      final db = await _dbProvider.database;
      int restoredCalcs = 0;
      int restoredEntries = 0;

      await db.transaction((txn) async {
        if (replaceAll) {
          await txn.delete('measurement_entries');
          await txn.delete('calculations');
        }

        for (final item in rawCalculations) {
          if (item is! Map<String, dynamic>) continue;

          final nowUtc = DateTime.now().toUtc().toIso8601String();
          final calcMap = <String, dynamic>{
            'title': item['title'] as String? ?? 'Restored Calculation',
            'calculation_date': item['calculation_date'] as String? ?? nowUtc.substring(0, 10),
            'calculation_time': item['calculation_time'] as String? ?? nowUtc.substring(11, 16),
            'created_at_utc': item['created_at_utc'] as String? ?? nowUtc,
            'updated_at_utc': nowUtc,
          };

          final calcId = await txn.insert('calculations', calcMap);
          restoredCalcs++;

          final rawEntries = item['entries'];
          if (rawEntries is List) {
            for (int i = 0; i < rawEntries.length; i++) {
              final e = rawEntries[i];
              if (e is! Map<String, dynamic>) continue;

              final entryMap = <String, dynamic>{
                'calculation_id': calcId,
                'sort_order': e['sort_order'] as int? ?? i,
                'purpose': e['purpose'] as String? ?? 'Nil',
                'operation': e['operation'] == 'SUBTRACT' ? 'SUBTRACT' : 'ADD',
                'kanal': (e['kanal'] as num?)?.toInt() ?? 0,
                'marla': (e['marla'] as num?)?.toInt() ?? 0,
                'sarsai_centi': (e['sarsai_centi'] as num?)?.toInt() ?? 0,
              };

              await txn.insert('measurement_entries', entryMap);
              restoredEntries++;
            }
          }
        }
      });

      return BackupRestoreResult(
        success: true,
        calculationsCount: restoredCalcs,
        entriesCount: restoredEntries,
      );
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        errorMessage: 'Failed to restore backup: $e',
      );
    }
  }

  /// Clears all database records completely in an atomic transaction
  Future<int> clearAllData() async {
    final db = await _dbProvider.database;
    return await db.transaction<int>((txn) async {
      final entriesDeleted = await txn.delete('measurement_entries');
      final calcsDeleted = await txn.delete('calculations');
      try {
        await txn.rawDelete("DELETE FROM sqlite_sequence WHERE name IN ('calculations', 'measurement_entries')");
      } catch (_) {
        // Ignored if sqlite_sequence does not exist
      }
      return calcsDeleted + entriesDeleted;
    });
  }
}
