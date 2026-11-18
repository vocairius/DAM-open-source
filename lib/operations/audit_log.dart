import 'dart:convert';

import '../database/database.dart';

/// Registro de auditoría de operaciones destructivas y edición masiva.
///
/// Permite revertir o auditar cualquier operación posterior.
class AuditLog {
  final AppDatabase db;

  AuditLog(this.db);

  /// Registra una operación (ej. bulk tag apply, bulk delete, bulk move).
  Future<void> log({
    required String operation,
    required Map<String, dynamic> payload,
    bool reversible = true,
  }) async {
    final db = await this.db.open();
    await db.insert('operations_log', {
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'reversible': reversible ? 1 : 0,
    });
  }

  /// Obtiene el historial de operaciones (últimas [limit]).
  Future<List<LogEntry>> history({int limit = 100}) async {
    final db = await this.db.open();
    final rows = await db.query(
      'operations_log',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((r) => LogEntry.fromJson(r)).toList();
  }

  /// Busca una entrada por ID y devuelve su payload para posible reversión.
  Future<LogEntry?> getEntry(int id) async {
    final db = await this.db.open();
    final rows = await db.query(
      'operations_log',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LogEntry.fromJson(rows.first);
  }
}

/// Entrada del log de auditoría.
class LogEntry {
  final int id;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final bool reversible;

  LogEntry({
    required this.id,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.reversible,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        id: json['id'] as int,
        operation: json['operation'] as String,
        payload:
            jsonDecode(json['payload_json'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(json['created_at'] as String),
        reversible: (json['reversible'] as int) == 1,
      );
}
