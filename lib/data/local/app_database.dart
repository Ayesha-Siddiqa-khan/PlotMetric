import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/constants/scheme_catalog.dart';

class AppDatabase {
  static const String databaseName = 'plotmetric.db';
  static const int databaseVersion = 4;

  static AppDatabase? _instance;
  static Database? _database;
  static bool _ffiInitialized = false;

  AppDatabase._();

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && !_ffiInitialized && !Platform.environment.containsKey('FLUTTER_TEST') &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, databaseName);

    return await openDatabase(
      path,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _createSchemeTables(db);
        await _seedSchemeRegister(db);
        await _createApprovedLandTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createSchemeTables(db);
        if (oldVersion < 3) await _seedSchemeRegister(db);
        if (oldVersion < 4) await _createApprovedLandTables(db);
      },
    );
  }

  Future<void> _seedSchemeRegister(Database db) async {
    await db.execute("""
      INSERT OR IGNORE INTO scheme_register (name)
      SELECT trim(name) FROM housing_schemes WHERE length(trim(name)) BETWEEN 1 AND 120
    """);
    for (final name in SchemeCatalog.colonies) {
      await db.insert('scheme_register', {'name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _createApprovedLandTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS approved_land (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        serial INTEGER,
        name TEXT NOT NULL,
        owner TEXT NOT NULL DEFAULT '',
        mouza TEXT NOT NULL DEFAULT '',
        total_area TEXT NOT NULL DEFAULT '',
        transfer_total TEXT NOT NULL DEFAULT '',
        transferred TEXT NOT NULL DEFAULT '',
        remaining TEXT NOT NULL DEFAULT '',
        mortgage TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        scheme_id INTEGER REFERENCES housing_schemes(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS approved_land_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSchemeTables(Database db) async {
    await db.execute('''
      CREATE TABLE housing_schemes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        owner TEXT NOT NULL,
        approval TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE scheme_images (
        scheme_id INTEGER NOT NULL REFERENCES housing_schemes(id) ON DELETE CASCADE,
        slot INTEGER NOT NULL,
        image BLOB NOT NULL,
        PRIMARY KEY (scheme_id, slot)
      )
    ''');
    await db.execute('''
      CREATE TABLE scheme_register (
        name TEXT NOT NULL COLLATE NOCASE PRIMARY KEY
      )
    ''');
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE calculations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        calculation_date TEXT NOT NULL,
        calculation_time TEXT NOT NULL,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE measurement_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        calculation_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        purpose TEXT NOT NULL DEFAULT 'Nil',
        operation TEXT NOT NULL CHECK (operation IN ('ADD', 'SUBTRACT')),
        kanal INTEGER NOT NULL DEFAULT 0 CHECK (kanal BETWEEN 0 AND 1000000),
        marla INTEGER NOT NULL DEFAULT 0 CHECK (marla BETWEEN 0 AND 19),
        sarsai_centi INTEGER NOT NULL DEFAULT 0 CHECK (sarsai_centi BETWEEN 0 AND 899),
        FOREIGN KEY (calculation_id) REFERENCES calculations(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_calculations_updated_at ON calculations(updated_at_utc DESC);
    ''');

    await db.execute('''
      CREATE INDEX idx_entries_calculation_order ON measurement_entries(calculation_id, sort_order);
    ''');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
