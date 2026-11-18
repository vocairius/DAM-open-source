/// Tipos de activos multimedia indexados por Vault DAM.
///
/// Alternativa a enums globales: una sola enumeración centralizada evita la
/// inconsistencia entre las capas de modelo, repositorio y UI.
enum AssetType {
  /// Archivos de video (mp4, mov, mkv, avi, ...)
  video,

  /// Archivos de audio (mp3, wav, aiff, flac, ...)
  audio,

  /// Imágenes (jpg, png, tiff, exr, psd, ...)
  image,

  /// Archivos de proyecto (prpro, fcpxml, drp, ...)
  project,

  /// Fuentes tipográficas (ttf, otf, otf, fnt, ...)
  font,

  /// Documentos (pdf, docx, txt, md, ...)
  document,

  /// Cualquier otro archivo binario no clasificado.
  other,
}

/// Expansión de cada tipo en extensiones de archivo comunes para su clasificación
/// automática.
final _typeExtensions = <AssetType, List<String>>{
  AssetType.video: [
    'mp4',
    'mov',
    'mkv',
    'avi',
    'webm',
    'm4v',
    'mpg',
    'mpeg',
    'flv',
    'wmv',
  ],
  AssetType.audio: [
    'mp3',
    'wav',
    'aiff',
    'flac',
    'aac',
    'ogg',
    'wma',
    'm4a',
    'opus',
  ],
  AssetType.image: [
    'jpg',
    'jpeg',
    'png',
    'tiff',
    'tif',
    'exr',
    'psd',
    'ai',
    'svg',
    'gif',
    'bmp',
    'webp',
    'heic',
  ],
  AssetType.project: [
    'prpro',
    'fcpxml',
    'drp',
    'aep',
    'pdtn',
    'blend',
    'ma',
    'mb',
  ],
  AssetType.font: ['ttf', 'otf', 'ttc', 'woff', 'woff2', 'fnt'],
  AssetType.document: [
    'pdf',
    'docx',
    'doc',
    'txt',
    'md',
    'rtf',
    'odt',
    'xls',
    'xlsx',
    'csv',
  ],
};

/// Determina el tipo de activo a partir de la extensión del nombre del archivo
/// (ignorando mayúsculas/minúsculas). Si la extensión no coincide con ninguna
/// categoría predefinida, el tipo es [AssetType.other].
AssetType? typeByExtension(String extension) {
  final normalized = extension.toLowerCase();
  for (final entry in _typeExtensions.entries) {
    if (entry.value.contains(normalized)) {
      return entry.key;
    }
  }
  return null;
}

/// Etiquetas de color tipo "Label" (azul/rojo/amarillo/etc.) para clasificación
/// visual.
enum ColorLabel {
  red(colorCode: 0xFFE44B4F),
  orange(colorCode: 0xFFFFA842),
  yellow(colorCode: 0xFFF4C430),
  green(colorCode: 0xFF44BA65),
  blue(colorCode: 0xFF33A7DC),
  purple(colorCode: 0xFF9D6FD1),
  gray(colorCode: 0xFF7C7C7C),
  none(colorCode: 0xFF000000);

  final int colorCode;

  const ColorLabel({required this.colorCode});

  String toCssHex() => '#${colorCode.toRadixString(16).padLeft(8, '0')}';
}

/// Calificación por estrellas de un activo (0..5).
enum Rating {
  none(null),
  one(1),
  two(2),
  three(3),
  four(4),
  five(5);

  final int? stars;

  const Rating(this.stars);

  /// Número entero de estrellas (null = sin calificación).
  int? toStars() => stars;

  /// Devuelve la representación entera de comparación (útil para sorting).
  int get compareKey => stars ?? -1;
}
