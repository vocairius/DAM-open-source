import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault_dam/database/app_database.dart';
import 'package:vault_dam/operations/audit_log.dart';
import 'package:vault_dam/operations/soft_delete.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('vault-dam-ops-');
    database = AppDatabase('${tempDirectory.path}/metadata.db');
  });

  tearDown(() async {
    await database.close();
    await tempDirectory.delete(recursive: true);
  });

  test('soft-deletes and restores an asset with an audit trail', () async {
    final original = File('${tempDirectory.path}/original.mp4');
    await original.writeAsString('original bytes');
    final db = await database.open();
    final assetId = await db.insert('assets', {
      'path': original.path,
      'hash': 'synthetic-hash',
      'type': 'video',
      'size': 14,
      'imported_at': DateTime.now().toIso8601String(),
      'modified_at': DateTime.now().toIso8601String(),
    });

    final service = SoftDeleteService(database);
    final deletion = await service.delete(assetId);
    var row = (await db.query(
      'assets',
      where: 'id = ?',
      whereArgs: [assetId],
    ))
        .single;
    expect(row['deleted_at'], deletion.deletedAt.toIso8601String());
    expect(await original.readAsString(), 'original bytes');

    await service.restore(assetId);
    row = (await db.query(
      'assets',
      where: 'id = ?',
      whereArgs: [assetId],
    ))
        .single;
    expect(row['deleted_at'], isNull);

    final history = await AuditLog(database).history();
    expect(history.map((entry) => entry.operation), [
      'restore_asset',
      'soft_delete',
    ]);
    expect(history.last.payload['asset_id'], assetId);
  });

  test('rejects deleting an asset that does not exist', () async {
    await database.open();
    await expectLater(
      SoftDeleteService(database).delete(123),
      throwsA(isA<StateError>()),
    );
  });
}
