import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../indexing/indexer.dart';
import '../model/asset.dart';
import '../model/asset_catalog.dart';
import '../model/cancel_token.dart';

class SqliteAssetCatalog implements AssetCatalog {
  SqliteAssetCatalog(this.indexer);

  final Indexer indexer;

  @override
  Future<List<Asset>> listAssets() async {
    try {
      return await indexer.listAssets();
    } on DatabaseException catch (error) {
      throw AssetCatalogException('No se pudo leer el catálogo local: $error');
    }
  }

  @override
  Future<Asset> indexFile(String path, {CancelToken? cancelToken}) async {
    try {
      return await indexer.indexFile(path, cancelToken: cancelToken);
    } on DatabaseException catch (error) {
      throw AssetCatalogException('No se pudo guardar el activo: $error');
    }
  }

  @override
  Future<int> indexDirectory({
    required String root,
    required CancelToken cancelToken,
    required void Function(int processed, String? currentPath) onProgress,
  }) async {
    try {
      final result = await indexer.indexDirectory(
        root: root,
        cancelToken: cancelToken,
        onProgress: (progress) async {
          onProgress(progress.processed, progress.currentPath);
        },
      );
      return result.processed;
    } on DatabaseException catch (error) {
      throw AssetCatalogException(
        'No se pudo guardar el catálogo de la carpeta: $error',
      );
    }
  }

  @override
  Future<void> updateCategory(String path, String category) async {
    try {
      final database = await indexer.db.open();
      await database.update(
        'assets',
        {'category': category},
        where: 'path = ?',
        whereArgs: [path],
      );
    } on DatabaseException catch (error) {
      throw AssetCatalogException(
        'No se pudo guardar la categoría: $error',
      );
    }
  }
}
