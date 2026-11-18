import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static const String databaseName = 'plotmetric.db';
  static const int databaseVersion = 1;

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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Routine upgrades must preserve existing user tables
      },
    );
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
