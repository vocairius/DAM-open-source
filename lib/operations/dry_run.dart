/// Dry-run (vista previa) para operaciones automáticas de organización.
///
/// Antes de mover/renombrar por reglas, se muestra al usuario qué cambios
/// ocurrirían. La spec exige modo "vista previa" obligatorio.
class DryRunResult {
  final List<DryRunChange> changes;

  const DryRunResult(this.changes);

  int get totalChanges => changes.length;
  int get additions => changes.where((c) => c.kind == ChangeKind.add).length;
  int get modifications =>
      changes.where((c) => c.kind == ChangeKind.modify).length;
  int get deletions => changes.where((c) => c.kind == ChangeKind.delete).length;
}

/// Tipo de cambio en una operación de organización.
enum ChangeKind { add, modify, delete }

/// Un cambio individual mostrado en dry-run.
class DryRunChange {
  final ChangeKind kind;
  final String fromPath;
  final String toPath;
  final Map<String, dynamic>? metadata;

  const DryRunChange({
    required this.kind,
    required this.fromPath,
    required this.toPath,
    this.metadata,
  });
}
