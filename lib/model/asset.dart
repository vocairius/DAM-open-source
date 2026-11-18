import 'asset_type.dart';

/// Activo indexado. Inmutable por diseño: toda mutación devuelve una nueva
/// instancia para hacer las operaciones rastreables y reversibles.
///
/// Regla de la spec: el archivo original nunca se modifica. Solo esta tabla de
/// metadatos es lo que Vault DAM escribe en disco.
class Asset {
  final int? id;
  final String path;
  final String hash;
  final AssetType type;
  final int size;
  final int? width;
  final int? height;
  final Duration? duration;
  final DateTime importedAt;
  final DateTime modifiedAt;
  final int? rating;
  final String category;
  final ColorLabel colorLabel;
  final String notes;
  final DateTime? deletedAt;

  Asset({
    this.id,
    required this.path,
    required this.hash,
    required this.type,
    required this.size,
    this.width,
    this.height,
    this.duration,
    DateTime? importedAt,
    DateTime? modifiedAt,
    this.rating,
    this.category = '',
    this.colorLabel = ColorLabel.none,
    this.notes = '',
    this.deletedAt,
  })  : importedAt = importedAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  Asset copyWith({
    int? id,
    String? path,
    String? hash,
    AssetType? type,
    int? size,
    int? width,
    int? height,
    Duration? duration,
    DateTime? importedAt,
    DateTime? modifiedAt,
    int? rating,
    String? category,
    ColorLabel? colorLabel,
    String? notes,
    DateTime? deletedAt,
  }) =>
      Asset(
        id: id ?? this.id,
        path: path ?? this.path,
        hash: hash ?? this.hash,
        type: type ?? this.type,
        size: size ?? this.size,
        width: width ?? this.width,
        height: height ?? this.height,
        duration: duration ?? this.duration,
        importedAt: importedAt ?? this.importedAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        rating: rating ?? this.rating,
        category: category ?? this.category,
        colorLabel: colorLabel ?? this.colorLabel,
        notes: notes ?? this.notes,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  /// Duplicado exacto por hash.
  bool isDuplicateOf(Asset other) => hash == other.hash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Asset && hash == other.hash && path == other.path;

  @override
  int get hashCode => Object.hash(hash, path);

  Map<String, dynamic> toDatabaseRow() => {
        'path': path,
        'hash': hash,
        'type': type.name,
        'size': size,
        'width': width,
        'height': height,
        'duration_ms': duration?.inMilliseconds,
        'imported_at': importedAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String(),
        'rating': rating,
        'category': category,
        'color_label': colorLabel.name,
        'notes': notes,
        'deleted_at': deletedAt?.toIso8601String(),
      };

  factory Asset.fromDatabaseRow(Map<String, Object?> json) => Asset(
        id: json['id'] as int?,
        path: json['path'] as String,
        hash: json['hash'] as String,
        type: AssetType.values.firstWhere(
          (type) => type.name == json['type'],
          orElse: () => AssetType.other,
        ),
        size: (json['size'] as num?)?.toInt() ?? 0,
        width: json['width'] as int?,
        height: json['height'] as int?,
        duration: json['duration_ms'] is int
            ? Duration(milliseconds: json['duration_ms']! as int)
            : null,
        importedAt: json['imported_at'] != null
            ? DateTime.parse(json['imported_at']! as String)
            : DateTime.now(),
        modifiedAt: json['modified_at'] != null
            ? DateTime.parse(json['modified_at']! as String)
            : DateTime.now(),
        rating: json['rating'] is int ? json['rating']! as int : null,
        category: json['category'] as String? ?? '',
        colorLabel: json['color_label'] != null
            ? ColorLabel.values.firstWhere(
                (c) => c.name == json['color_label'],
                orElse: () => ColorLabel.none,
              )
            : ColorLabel.none,
        notes: json['notes'] as String? ?? '',
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.parse(json['deleted_at']! as String),
      );
}

/// Licencia de activo de Envato (solo aplica a activos de origen Envato).
/// Campos locales: tipo de licencia, software compatible, autor/fuente.
class License {
  final int? id;
  final int assetId;
  final String licenseType;
  final List<String> compatibleSoftware;
  final String? author;
  final String? source;

  const License({
    this.id,
    required this.assetId,
    required this.licenseType,
    this.compatibleSoftware = const [],
    this.author,
    this.source,
  });

  /// Software común con licencias de Envato Elements.
  static const commonSoftware = [
    'After Effects',
    'Premiere Pro',
    'DaVinci Resolve',
    'Final Cut Pro',
    'Photoshop',
    'Illustrator',
    'Audition',
    'Cinema 4D',
  ];

  License copyWith({
    String? licenseType,
    List<String>? compatibleSoftware,
    String? author,
    String? source,
  }) =>
      License(
        id: id,
        assetId: assetId,
        licenseType: licenseType ?? this.licenseType,
        compatibleSoftware: compatibleSoftware ?? this.compatibleSoftware,
        author: author ?? this.author,
        source: source ?? this.source,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is License && id != null && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
