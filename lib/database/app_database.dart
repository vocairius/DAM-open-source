import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'migrations.dart';

typedef DatabaseDowngradeHandler = Future<void> Function(
  Database db,
  int oldVersion,
  int newVersion,
);

class DbBackup {
  final Directory backupDir;

  DbBackup(this.backupDir);

  Future<String> backupBeforeMigration({
    required String dbPath,
    required int fromVersion,
    required int toVersion,
  }) async {
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw FileSystemException(
        'Database file is missing before migration',
        dbPath,
      );
    }

    await backupDir.create(recursive: true);
    final timestamp =
        DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final backupName = '$timestamp-v$fromVersion-to-v$toVersion.db';
    final backupPath = p.join(backupDir.path, backupName);
    await dbFile.copy(backupPath);
    return backupPath;
  }
}

const int targetSchemaVersion = 2;

class AppDatabase {
  final String dbPath;
  final DbBackup backup;
  final int targetVersion;

  AppDatabase(
    this.dbPath, {
    DbBackup? backup,
    this.targetVersion = targetSchemaVersion,
  }) : backup = backup ??
            DbBackup(Directory(p.join(p.dirname(dbPath), 'backups'))) {
    if (targetVersion < 0) {
      throw ArgumentError.value(targetVersion, 'targetVersion');
    }
  }

  Database? _db;

  Future<Database> open({bool applyMigrations = true}) async {
    final cached = _db;
    if (cached != null) return cached;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await Directory(p.dirname(dbPath)).create(recursive: true);

    final databaseFile = File(dbPath);
    var currentVersion = InitialMigration.schemaVersion;
    Database? migratedDb;
    if (!await databaseFile.exists() || await databaseFile.length() == 0) {
      migratedDb = await _openAtVersion(currentVersion);
    } else {
      final probe = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          onConfigure: (Database db) async =>
              db.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      currentVersion = await probe.getVersion();
      await probe.close();
    }

    if (!applyMigrations && currentVersion != targetVersion) {
      await migratedDb?.close();
      throw StateError(
        'Database schema is version $currentVersion; '
        'version $targetVersion is required.',
      );
    }

    while (currentVersion < targetVersion) {
      final nextVersion = currentVersion + 1;
      _migrationFor(nextVersion);
      await migratedDb?.close();
      await backup.backupBeforeMigration(
        dbPath: dbPath,
        fromVersion: currentVersion,
        toVersion: nextVersion,
      );
      migratedDb = await _openAtVersion(nextVersion);
      currentVersion = nextVersion;
    }

    while (currentVersion > targetVersion) {
      final migration = _migrationFor(currentVersion);
      final nextVersion = currentVersion - 1;
      await migratedDb?.close();
      await backup.backupBeforeMigration(
        dbPath: dbPath,
        fromVersion: currentVersion,
        toVersion: nextVersion,
      );
      migratedDb = await _openAtVersion(
        nextVersion,
        onDowngrade: (db, oldVersion, newVersion) async {
          await _executeSql(db, migration.downSql);
          await db.execute(
            'UPDATE schema_version SET version = ${migration.version - 1}',
          );
        },
      );
      currentVersion = nextVersion;
    }

    _db = migratedDb ?? await _openAtVersion(targetVersion);
    return _db!;
  }

  Migration _migrationFor(int version) {
    for (final migration in registeredMigrations) {
      if (migration.version == version) return migration;
    }
    throw StateError('No migration is registered for schema version $version.');
  }

  Future<Database> _openAtVersion(
    int version, {
    DatabaseDowngradeHandler? onDowngrade,
  }) {
    return databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: onDowngrade ?? _onDowngrade,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
        },
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _executeSql(db, InitialMigration().upSql);
    await db.execute('UPDATE schema_version SET version = $version');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final pending = registeredMigrations
        .where(
          (migration) =>
              migration.version > oldVersion && migration.version <= newVersion,
        )
        .toList()
      ..sort((a, b) => a.version.compareTo(b.version));

    for (final migration in pending) {
      await _executeSql(db, migration.upSql);
      await db.execute(
        'UPDATE schema_version SET version = ${migration.version}',
      );
    }
  }

  Future<void> _onDowngrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    final rollback = registeredMigrations
        .where(
          (migration) =>
              migration.version > newVersion && migration.version <= oldVersion,
        )
        .toList()
      ..sort((a, b) => b.version.compareTo(a.version));

    for (final migration in rollback) {
      await _executeSql(db, migration.downSql);
      await db.execute(
        'UPDATE schema_version SET version = ${migration.version - 1}',
      );
    }
  }

  Future<void> _executeSql(DatabaseExecutor db, String statements) async {
    for (final statement
        in statements.split(';').where((sql) => sql.trim().isNotEmpty)) {
      await db.execute(statement);
    }
  }

  Future<int> currentVersion() async {
    final db = _db ?? await open();
    final result = await db.query('schema_version', columns: ['version']);
    if (result.length != 1) {
      throw StateError('Database must contain exactly one schema version.');
    }
    return result.single['version']! as int;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
