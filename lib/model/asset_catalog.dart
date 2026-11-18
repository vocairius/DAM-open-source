import 'asset.dart';
import 'cancel_token.dart';

abstract interface class AssetCatalog {
  Future<List<Asset>> listAssets();

  Future<Asset> indexFile(String path, {CancelToken? cancelToken});

  Future<int> indexDirectory({
    required String root,
    required CancelToken cancelToken,
    required void Function(int processed, String? currentPath) onProgress,
  });

  Future<void> updateCategory(String path, String category);
}

class AssetCatalogException implements Exception {
  const AssetCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AssetReadException implements Exception {
  const AssetReadException(this.message);

  final String message;

  @override
  String toString() => message;
}
