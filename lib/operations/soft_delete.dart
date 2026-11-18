import 'dart:convert';

import '../database/database.dart';

/// Papelera interna (soft delete) para cualquier borrado iniciado desde la app.
///
/// Nunca se borra el archivo original directamente sin confirmación y opción de
/// deshacer. El asset se marca con deleted_at y se puede restaurar.
class SoftDelete {
  final int assetId;
  final DateTime deletedAt;

  const SoftDelete(this.assetId, this.deletedAt);

  factory SoftDelete.now(int assetId) => SoftDelete(assetId, DateTime.now());

  /// Genera el SQL para marcar el asset como borrado suavemente.
  Map<String, dynamic> toSql() => {
        'deleted_at': deletedAt.toIso8601String(),
      };

  /// Genera el SQL para restaurar (deshacer) el soft delete.
  Map<String, dynamic> toRestoreSql() => {
        'deleted_at': null,
      };
}

class SoftDeleteService {
  final AppDatabase database;

  SoftDeleteService(this.database);

  Future<SoftDelete> delete(int assetId) async {
    final db = await database.open();
    final deletedAt = DateTime.now();
    await db.transaction((transaction) async {
      final assets = await transaction.query(
        'assets',
        columns: ['id', 'deleted_at'],
        where: 'id = ?',
        whereArgs: [assetId],
        limit: 1,
      );
      if (assets.isEmpty) {
        throw StateError('Asset $assetId does not exist.');
      }
      if (assets.single['deleted_at'] != null) {
        throw StateError('Asset $assetId is already in the internal trash.');
      }

      final timestamp = deletedAt.toIso8601String();
      await transaction.update(
        'assets',
        {'deleted_at': timestamp},
        where: 'id = ?',
        whereArgs: [assetId],
      );
      await transaction.insert('operations_log', {
        'operation': 'soft_delete',
        'payload_json': jsonEncode({
          'asset_id': assetId,
          'deleted_at': timestamp,
        }),
        'created_at': timestamp,
        'reversible': 1,
      });
    });
    return SoftDelete(assetId, deletedAt);
  }

  Future<void> restore(int assetId) async {
    final db = await database.open();
    final restoredAt = DateTime.now().toIso8601String();
    await db.transaction((transaction) async {
      final assets = await transaction.query(
        'assets',
        columns: ['id', 'deleted_at'],
        where: 'id = ?',
        whereArgs: [assetId],
        limit: 1,
      );
      if (assets.isEmpty) {
        throw StateError('Asset $assetId does not exist.');
      }
      if (assets.single['deleted_at'] == null) {
        throw StateError('Asset $assetId is not in the internal trash.');
      }

      await transaction.update(
        'assets',
        {'deleted_at': null},
        where: 'id = ?',
        whereArgs: [assetId],
      );
      await transaction.insert('operations_log', {
        'operation': 'restore_asset',
        'payload_json': jsonEncode({'asset_id': assetId}),
        'created_at': restoredAt,
        'reversible': 1,
      });
    });
  }
}
