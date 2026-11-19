import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:plotmetric/data/local/app_database.dart';
import 'package:plotmetric/features/approved_land/logic/approved_land.dart';
import 'package:plotmetric/features/approved_land/logic/approved_land_repository.dart';
import 'package:plotmetric/features/approved_land/logic/approved_land_seed.dart';
import 'package:plotmetric/features/schemes/logic/scheme.dart';
import 'package:plotmetric/features/schemes/logic/scheme_repository.dart';
import 'package:plotmetric/features/settings/logic/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('area text', () {
    test('every printed total area in the seed is read, except the one that is invalid on the sheet', () {
      final unreadable = [
        for (final row in approvedLandSeed)
          if (LandAreaText.parse(row.total) == null) row.serial,
      ];
      expect(unreadable, [26]); // "51K 35M": Marla cannot exceed 19
      expect(approvedLandSeed, hasLength(49));
      expect(approvedLandSeed.any((row) => row.serial == 38), isFalse);
    });

    test('source formats normalise to K-M-S', () {
      expect(LandAreaText.normalize('98K'), '98K-0M-0S');
      expect(LandAreaText.normalize('91 K 16 M'), '91K-16M-0S');
      expect(LandAreaText.normalize('49K 05M 5S'), '49K-5M-5S');
      expect(LandAreaText.normalize('18K-12M-05S'), '18K-12M-5S');
      expect(LandAreaText.normalize('8k-7M'), '8K-7M-0S');
      expect(LandAreaText.normalize('02 K'), '2K-0M-0S');
      expect(LandAreaText.normalize('93k-17M'), '93K-17M-0S');
      // Invalid text is kept exactly as typed.
      expect(LandAreaText.normalize('51K 35M'), '51K-35M'); // invalid, but dashed like the others
      expect(LandAreaText.normalize('note'), 'note');
      expect(LandAreaText.normalize('-'), '-');
    });

    test('remaining is transfer area less transferred', () {
      expect(ApprovedLandEntry.computeRemaining('18K-6M-8S', '5K'), '13K-6M-8S');
      expect(ApprovedLandEntry.computeRemaining('18K-6M-8S', ''), '18K-6M-8S');
      expect(ApprovedLandEntry.computeRemaining('', '5K'), '');
      expect(ApprovedLandEntry.computeRemaining('1K', '2K'), '-1K-0M-0S');
    });
  });

  test('register is seeded once, editable, linked to scans and part of backups', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final build = await Directory('build').create(recursive: true);
    final folder = await build.createTemp('approved_land_test_');
    addTearDown(() async {
      await AppDatabase.instance.close();
      await folder.delete(recursive: true);
    });
    await databaseFactory.setDatabasesPath(folder.absolute.path);
    // A database from before this feature (version 3) must upgrade cleanly.
    final legacy = await databaseFactory.openDatabase(
      p.join(folder.absolute.path, AppDatabase.databaseName),
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE calculations (id INTEGER PRIMARY KEY, title TEXT, calculation_date TEXT, calculation_time TEXT, created_at_utc TEXT, updated_at_utc TEXT)',
          );
          await db.execute(
            'CREATE TABLE measurement_entries (id INTEGER PRIMARY KEY, calculation_id INTEGER, sort_order INTEGER, purpose TEXT, operation TEXT, kanal INTEGER, marla INTEGER, sarsai_centi INTEGER)',
          );
          await db.execute(
            'CREATE TABLE housing_schemes (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, owner TEXT NOT NULL, approval TEXT NOT NULL, updated_at TEXT NOT NULL, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE scheme_images (scheme_id INTEGER NOT NULL, slot INTEGER NOT NULL, image BLOB NOT NULL, PRIMARY KEY (scheme_id, slot))',
          );
          await db.execute('CREATE TABLE scheme_register (name TEXT NOT NULL COLLATE NOCASE PRIMARY KEY)');
        },
      ),
    );
    await legacy.close();

    final repo = ApprovedLandRepository();
    final first = await repo.all();
    expect(first, hasLength(49));
    expect(first.first.name, 'Al khair housing colony');
    expect(first.first.totalArea, '98K-0M-0S');
    expect(first.first.remaining, '18K-12M-5S');
    expect(first[1].mortgage, '6K-0M-0S');
    expect(first.firstWhere((e) => e.serial == 4).transferred, '39K-8M-0S');
    expect(first.firstWhere((e) => e.serial == 26).totalArea, '51K-35M');

    // Edit, delete, add: none of it is undone by reopening.
    final khair = first.first..owner = 'Edited owner';
    await repo.save(khair);
    await repo.delete(first[1].id!);
    final added = ApprovedLandEntry(name: 'My New Colony', totalArea: '10K');
    await repo.save(added);
    expect(added.serial, 51); // after the highest printed Sr.No
    final second = await repo.all();
    expect(second, hasLength(49));
    expect(second.first.owner, 'Edited owner');
    expect(second.any((e) => e.name == 'MODEL TOWN'), isFalse);
    expect(second.last.name, 'My New Colony');

    // A saved scan fills the transfer columns.
    final scan = HousingScheme()..name = 'My New Colony';
    await SchemeRepository().save(scan);
    await repo.applyScan(
      added.id!,
      schemeId: scan.id!,
      transferArea: LandAreaText.parse('4K-2M-0S')!,
      transferred: '1K',
      totalAreaIfEmpty: '99K-0M-0S',
    );
    final scanned = (await repo.byId(added.id!))!;
    expect(scanned.transferTotal, '4K-2M-0S');
    expect(scanned.transferred, '1K-0M-0S');
    expect(scanned.remaining, '3K-2M-0S');
    expect(scanned.totalArea, '10K'); // the register's own total is kept
    expect(scanned.schemeId, scan.id);
    expect((await repo.byName(' my new colony '))!.id, added.id);

    // Saving a scan with nothing ticked links it without wiping the transfer figures.
    await repo.applyScan(added.id!, schemeId: scan.id!);
    final relinked = (await repo.byId(added.id!))!;
    expect(relinked.transferTotal, '4K-2M-0S');
    expect(relinked.remaining, '3K-2M-0S');

    // Backups carry the register, and restoring does not re-seed it.
    final backup = BackupService();
    final json = await backup.exportBackupJson();
    expect((jsonDecode(json) as Map)['approved_land'], hasLength(49));
    await repo.delete(added.id!);
    final restored = await backup.restoreFromJson(json, replaceAll: true);
    expect(restored.success, isTrue, reason: restored.errorMessage);
    final afterRestore = await repo.all();
    expect(afterRestore, hasLength(49));
    expect(afterRestore.last.name, 'My New Colony');

    // Clearing all data empties the register and it stays empty.
    await backup.clearAllData();
    expect(await repo.all(), isEmpty);
  });
}
