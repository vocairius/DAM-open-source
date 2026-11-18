import 'asset_type.dart';

/// Categoría jerárquica (puede tener padre/hijo). Inspirada en los tipos de activo
/// de Envato Elements: Plantillas de Video, Video de Stock, Audio, Gráficos,
/// Fuentes, Add-ons, LUTs, Plantillas de Presentación, etc.
///
/// El etiquetado de categoría de un activo es local (por carpeta de origen,
/// nombre de archivo o entrada manual); nunca se consulta la API de Envato (no
/// existe API pública y la spec lo prohíbe).
class Category {
  final int? id;
  final String name;
  final String slug;
  final Category? parent;

  Category({
    this.id,
    required this.name,
    String? slug,
    this.parent,
  }) : slug = slug ?? name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');

  /// Ruta jerárquica completa: "Video de Stock / Templates".
  String get hierarchy {
    if (parent == null) return name;
    return '${parent!.hierarchy} / $name';
  }

  /// Profundidad en la jerarquía (hojas = 1).
  int get depth => parent == null ? 1 : parent!.depth + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && id != null && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Colección: lista fija de activos (manual) o una regla guardada que se re-evalúa
/// sola (inteligente).
enum CollectionKind { manual, smart }

/// Representación serializable de una regla de colección inteligente. La regla se
/// re-evalúa contra el índice cuando se crece o cuando el usuario la modifica.
///
/// Ejemplo: tags contiene ["S-Log3"], category = "Video de Stock", types =
/// [video], minRating = 3.
class SmartRule {
  final List<String> tagNames;
  final String? categorySlug;
  final Set<AssetType> types;
  final int minRating;

  const SmartRule({
    this.tagNames = const [],
    this.categorySlug,
    Set<AssetType>? types,
    this.minRating = 0,
  }) : types = types ?? const {};

  /// Crea una regla a partir de un JSON.
  factory SmartRule.fromJson(Map<String, dynamic> json) {
    final typesRaw = json['types'] as List<dynamic>?;
    return SmartRule(
      tagNames: (json['tagNames'] as List<dynamic>?)?.cast<String>() ?? [],
      categorySlug: json['categorySlug'] as String?,
      types: typesRaw != null
          ? typesRaw
              .map(
                (e) => AssetType.values.firstWhere(
                  (t) => t.name == e,
                  orElse: () => AssetType.other,
                ),
              )
              .toSet()
          : const {},
      minRating: (json['minRating'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'tagNames': tagNames,
        'categorySlug': categorySlug,
        'types': types.map((t) => t.name).toList(),
        'minRating': minRating,
      };
}

/// Colección de activos.
class Collection {
  final int? id;
  final String name;
  final CollectionKind kind;
  final SmartRule? rule;
  final Set<int> assetIds;

  const Collection({
    this.id,
    required this.name,
    required this.kind,
    this.rule,
    Set<int>? assetIds,
  }) : assetIds = assetIds ?? const {};

  /// Colección manual: todos los activos listados explícitamente.
  bool get isManual => kind == CollectionKind.manual;

  /// Colección inteligente: la regla se re-evalúa contra el índice.
  bool get isSmart => kind == CollectionKind.smart;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Collection && id != null && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Carpeta vigilada: ruta del disco que se escanea automáticamente ante cambios
/// de archivos.
class WatchedFolder {
  final int? id;
  final String path;
  final bool enabled;
  final DateTime? lastScanAt;

  const WatchedFolder({
    this.id,
    required this.path,
    this.enabled = true,
    this.lastScanAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WatchedFolder && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
