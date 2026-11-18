import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault_dam/database/app_database.dart';
import 'package:vault_dam/database/migrations.dart';

void main() {
  late Directory tempDirectory;
  final databases = <AppDatabase>[];

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('vault-dam-db-');
    databases.clear();
  });

  tearDown(() async {
    for (final database in databases) {
      await database.close();
    }
    await tempDirectory.delete(recursive: true);
  });

  AppDatabase createDatabase({int targetVersion = targetSchemaVersion}) {
    final database = AppDatabase(
      '${tempDirectory.path}/metadata.db',
      targetVersion: targetVersion,
    );
    databases.add(database);
    return database;
  }

  test('creates the initial schema with foreign keys enabled', () async {
    final appDatabase = createDatabase();
    final db = await appDatabase.open();

    expect(await appDatabase.currentVersion(), 2);
    expect(await db.rawQuery('PRAGMA foreign_keys'), [
      {'foreign_keys': 1},
    ]);

    final columns = await db.rawQuery('PRAGMA table_info(assets)');
    expect(columns.map((row) => row['name']), contains('deleted_at'));
    expect(columns.map((row) => row['name']), contains('category'));
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('backs up and reverses each versioned migration without losing rows',
      () async {
    const v2Migration = Migration(
      version: 3,
      upSql:
          'ALTER TABLE assets ADD COLUMN migration_marker INTEGER NOT NULL DEFAULT 0;',
      downSql: 'ALTER TABLE assets DROP COLUMN migration_marker;',
    );
    registeredMigrations.add(v2Migration);

    try {
      final v1 = createDatabase();
      final v1Db = await v1.open();
      await v1Db.insert('assets', {
        'path': '${tempDirectory.path}/sample.mp4',
        'hash': 'abc',
        'type': 'video',
        'size': 3,
        'imported_at': DateTime.utc(2026).toIso8601String(),
        'modified_at': DateTime.utc(2026).toIso8601String(),
      });
      await v1.close();

      final v2 = createDatabase(targetVersion: 3);
      final v2Db = await v2.open();
      expect(await v2.currentVersion(), 3);
      expect(await v2Db.query('assets'), hasLength(1));
      await v2.close();

      final backups = Directory('${tempDirectory.path}/backups');
      expect(await backups.list().length, 2);

      final reverted = createDatabase();
      final revertedDb = await reverted.open();
      expect(await reverted.currentVersion(), 2);
      expect(await revertedDb.query('assets'), hasLength(1));
      final columns = await revertedDb.rawQuery('PRAGMA table_info(assets)');
      expect(
        columns.map((row) => row['name']),
        isNot(contains('migration_marker')),
      );
      expect(await backups.list().length, 3);
    } finally {
      registeredMigrations.remove(v2Migration);
    }
  });

  test('indexed filters stay below 300 ms for 10,000 synthetic rows', () async {
    final db = await createDatabase().open();
    final batch = db.batch();
    final timestamp = DateTime.utc(2026).toIso8601String();

    for (var index = 0; index < 10000; index++) {
      batch.insert('assets', {
        'path': '${tempDirectory.path}/synthetic-$index.mov',
        'hash': 'hash-$index',
        'type': index.isEven ? 'video' : 'image',
        'size': index,
        'imported_at': timestamp,
        'modified_at': timestamp,
        'rating': index % 6,
        'deleted_at': null,
      });
    }
    await batch.commit(noResult: true);

    final stopwatch = Stopwatch()..start();
    final results = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM assets '
      'WHERE type = ? AND rating >= ? AND deleted_at IS NULL',
      ['video', 3],
    );
    stopwatch.stop();

    expect(results.single['count'], 1666);
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 300)));
  });
}
