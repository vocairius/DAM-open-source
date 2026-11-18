import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/database.dart';
import '../model/asset.dart';
import '../model/asset_catalog.dart';
import '../model/asset_type.dart';
import 'hasher.dart';
import 'scanner.dart';

class Indexer {
  final AppDatabase db;
  final FileHasher hasher;
  final DirectoryScanner scanner;

  Indexer(
    this.db, {
    FileHasher? hasher,
    DirectoryScanner? scanner,
  })  : hasher = hasher ?? FileHasher(),
        scanner = scanner ?? DirectoryScanner();

  Future<bool> exists(String path, String hash) async {
    final database = await db.open();
    final rows = await database.query(
      'assets',
      columns: ['id'],
      where: 'path = ? AND hash = ?',
      whereArgs: [path, hash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Stores an asset by path; duplicate content at different paths remains
  /// indexed so the user can see and manage every original location.
  Future<void> upsert(Asset asset) async {
    final database = await db.open();
    final existing = await database.query(
      'assets',
      columns: ['id'],
      where: 'path = ?',
      whereArgs: [asset.path],
      limit: 1,
    );

    if (existing.isEmpty) {
      await database.insert('assets', asset.toDatabaseRow());
      return;
    }

    final id = existing.single['id']! as int;
    await database.update(
      'assets',
      {
        'hash': asset.hash,
        'type': asset.type.name,
        'size': asset.size,
        'width': asset.width,
        'height': asset.height,
        'duration_ms': asset.duration?.inMilliseconds,
        'modified_at': asset.modifiedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Asset>> listAssets() async {
    final database = await db.open();
    final rows = await database.query(
      'assets',
      where: 'deleted_at IS NULL',
      orderBy: 'imported_at DESC',
    );
    return rows.map(Asset.fromDatabaseRow).toList(growable: false);
  }

  Future<Asset> indexFile(String path, {CancelToken? cancelToken}) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const IndexingCancelledException();
    }
    try {
      final file = File(path);
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) {
        throw FileSystemException('Index target is not a regular file', path);
      }

      final asset = Asset(
        path: file.absolute.path,
        hash: await hasher.sha256(path, cancelToken: cancelToken),
        type: typeByExtension(p.extension(path).replaceFirst('.', '')) ??
            AssetType.other,
        size: stat.size,
        modifiedAt: stat.modified,
      );
      await upsert(asset);
      return asset;
    } on FileSystemException catch (error) {
      throw AssetReadException(
        'Could not read "$path": ${error.message}',
      );
    }
  }

  Future<ScanProgress> indexDirectory({
    required String root,
    required CancelToken cancelToken,
    required Future<void> Function(ScanProgress progress) onProgress,
    bool Function(String path)? fileFilter,
  }) {
    return scanner.scan(
      root: root,
      cancelToken: cancelToken,
      fileFilter: fileFilter ?? DirectoryScanner.defaultFileFilter,
      onProgress: (progress) async {
        final path = progress.currentPath;
        if (path != null && !cancelToken.isCancelled) {
          await indexFile(path, cancelToken: cancelToken);
        }
        await onProgress(progress);
      },
    );
  }
}
