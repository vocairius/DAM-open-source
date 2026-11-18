import 'asset_type.dart';

class Range<T> {
  final T start;
  final T end;

  const Range({required this.start, required this.end});
}

/// Etiqueta con jerarquía opcional (tag padre → hijos).
class Tag {
  final int? id;
  final String name;
  final String color;
  final Tag? parent;

  const Tag({
    this.id,
    required this.name,
    this.color = '#808080',
    this.parent,
  });

  /// Ruta jerárquica de la etiqueta ("Video / Color grading").
  String get hierarchy {
    if (parent == null) return name;
    return '${parent!.hierarchy} / $name';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tag && id != null && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Tag agregado a un activo (relación N:M).
class AssetTag {
  final int assetId;
  final int tagId;

  const AssetTag(this.assetId, this.tagId);

  @override
  bool operator ==(Object other) =>
      other is AssetTag && assetId == other.assetId && tagId == other.tagId;

  @override
  int get hashCode => Object.hash(assetId, tagId);
}

/// Regla de filtrado reutilizable (se aplica a búsquedas y colecciones inteligentes).
class FilterRule {
  final String? textQuery;
  final List<String>? tags;
  final String? categorySlug;
  final Set<AssetType>? types;
  final String? licenseType;
  final List<String>? compatibleSoftware;
  final int? minRating;
  final int? maxRating;
  final ColorLabel? colorLabel;
  final String? originFolder; // carpeta de origen (substring match)
  final Range<DateTime>? importedDateRange;
  final Range<int>? durationRange; // en milisegundos
  final Range<int>? resolutionRange; // pixeles totales width*height

  const FilterRule({
    this.textQuery,
    this.tags,
    this.categorySlug,
    this.types,
    this.licenseType,
    this.compatibleSoftware,
    this.minRating,
    this.maxRating,
    this.colorLabel,
    this.originFolder,
    this.importedDateRange,
    this.durationRange,
    this.resolutionRange,
  });

  /// Regla vacía (acepta todo).
  static const none = FilterRule();

  /// Combina dos reglas con AND.
  FilterRule and(FilterRule other) {
    return FilterRule(
      textQuery: textQuery ?? other.textQuery,
      tags: [...?tags, ...?other.tags],
      categorySlug: categorySlug ?? other.categorySlug,
      types: {...?types, ...?other.types},
      licenseType: licenseType ?? other.licenseType,
      compatibleSoftware: [
        ...?compatibleSoftware,
        ...?other.compatibleSoftware,
      ],
      minRating: minRating ?? other.minRating,
      maxRating: maxRating ?? other.maxRating,
      colorLabel: colorLabel ?? other.colorLabel,
      originFolder: originFolder ?? other.originFolder,
      importedDateRange: importedDateRange ?? other.importedDateRange,
      durationRange: durationRange ?? other.durationRange,
      resolutionRange: resolutionRange ?? other.resolutionRange,
    );
  }
}
