import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'database/sqlite_asset_catalog.dart';
import 'indexing/indexer.dart';
import 'prototype/vault_dam_ui_prototype.dart';
import 'thumbnails/generator.dart';
import 'model/asset_type.dart';

const _nativeChannel = MethodChannel('vault_dam/macOS');

Future<void> runVaultDam() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isMacOS) {
    throw UnsupportedError('Vault DAM desktop currently supports macOS only.');
  }
  final applicationSupport = await _nativeChannel.invokeMethod<String>(
    'applicationSupportDirectory',
  );
  if (applicationSupport == null || applicationSupport.isEmpty) {
    throw StateError('macOS did not provide an application support directory.');
  }

  final database = AppDatabase(p.join(applicationSupport, 'vault_dam.db'));
  final thumbnailGenerator =
      ThumbnailGenerator(p.join(applicationSupport, 'thumbnails'));
  runApp(
    VaultDamUiPrototype(
      catalog: SqliteAssetCatalog(Indexer(database)),
      showSampleAssets: false,
      revealSource: (path) async {
        await _nativeChannel.invokeMethod<void>('revealInFinder', path);
      },
      thumbnailGenerator: (path, type) async {
        if (type == AssetType.image) {
          final thumbnail =
              await thumbnailGenerator.generateImageThumb(path);
          return File(thumbnail).readAsBytes();
        }
        if (type == AssetType.video) {
          final thumbnail =
              await thumbnailGenerator.generateVideoThumb(path);
          return File(thumbnail).readAsBytes();
        }
        return null;
      },
    ),
  );
}
