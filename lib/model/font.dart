/// Fuente tipográfica indexada (subtipo de asset para modelado específico).
class Font {
  final String familyName;
  final String subfamily;
  final String? postscriptName;
  final int? weight;
  final int? width;

  const Font({
    required this.familyName,
    this.subfamily = 'Regular',
    this.postscriptName,
    this.weight,
    this.width,
  });
}
