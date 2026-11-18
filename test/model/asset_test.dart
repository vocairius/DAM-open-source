import 'package:flutter_test/flutter_test.dart';
import 'package:vault_dam/model/asset.dart';
import 'package:vault_dam/model/asset_type.dart';
import 'package:vault_dam/model/tag.dart';

void main() {
  test('asset database row round-trips typed metadata', () {
    final imported = DateTime.utc(2026, 1, 2);
    final modified = DateTime.utc(2026, 2, 3);
    final asset = Asset(
      id: 8,
      path: '/synthetic/clip.mov',
      hash: 'sha',
      type: AssetType.video,
      size: 100,
      width: 1920,
      height: 1080,
      duration: const Duration(seconds: 12),
      importedAt: imported,
      modifiedAt: modified,
      rating: 5,
      category: 'Video de stock',
      colorLabel: ColorLabel.blue,
      notes: 'test note',
      deletedAt: DateTime.utc(2026, 3, 4),
    );

    final restored = Asset.fromDatabaseRow({
      'id': 8,
      ...asset.toDatabaseRow(),
    });
    expect(restored.id, asset.id);
    expect(restored.type, AssetType.video);
    expect(restored.duration, asset.duration);
    expect(restored.colorLabel, ColorLabel.blue);
    expect(restored.importedAt, imported);
    expect(restored.deletedAt, asset.deletedAt);
    expect(restored.notes, 'test note');
    expect(restored.category, 'Video de stock');
  });

  test('classifies extensions without regard to case or leading dot', () {
    expect(typeByExtension('MOV'), AssetType.video);
    expect(typeByExtension('woff2'), AssetType.font);
    expect(typeByExtension('unknown'), isNull);
    expect(Rating.five.compareKey, 5);
    expect(Rating.none.compareKey, -1);
  });

  test('represents hierarchical tags and combines filter criteria', () {
    const parent = Tag(name: 'Video');
    const child = Tag(name: 'Color grading', parent: parent);
    expect(child.hierarchy, 'Video / Color grading');

    const first = FilterRule(tags: ['S-Log3'], types: {AssetType.video});
    const second = FilterRule(tags: ['4K'], minRating: 3);
    final combined = first.and(second);
    expect(combined.tags, ['S-Log3', '4K']);
    expect(combined.types, {AssetType.video});
    expect(combined.minRating, 3);
  });
}
