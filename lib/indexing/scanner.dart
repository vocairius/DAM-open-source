import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/cancel_token.dart';

export '../model/cancel_token.dart';

/// Resultado de un archivo procesado en el escaneo.
class ScanProgress {
  final int processed;
  final int? total;
  final String? currentPath;
  final bool cancelled;

  const ScanProgress({
    required this.processed,
    this.total,
    this.currentPath,
    this.cancelled = false,
  });
}

/// Escanea directorios en modo solo lectura y sin operaciones de listado síncronas.
class DirectoryScanner {
  Future<ScanProgress> scan({
    required String root,
    required Future<void> Function(ScanProgress progress) onProgress,
    required CancelToken cancelToken,
    bool Function(String path) fileFilter = defaultFileFilter,
  }) async {
    if (!await Directory(root).exists()) {
      throw FileSystemException('Scan root does not exist', root);
    }

    final stack = <String>[root];
    var processed = 0;
    String? currentPath;

    while (stack.isNotEmpty) {
      if (cancelToken.isCancelled) {
        return ScanProgress(
          processed: processed,
          currentPath: currentPath,
          cancelled: true,
        );
      }

      final current = stack.removeLast();
      await for (final entity
          in Directory(current).list(followLinks: false, recursive: false)) {
        if (cancelToken.isCancelled) {
          return ScanProgress(
            processed: processed,
            currentPath: currentPath,
            cancelled: true,
          );
        }

        if (entity is Directory) {
          if (!p.basename(entity.path).startsWith('.')) {
            stack.add(entity.path);
          }
        } else if (entity is File && fileFilter(entity.path)) {
          currentPath = entity.path;
          processed++;
          await onProgress(
            ScanProgress(
              processed: processed,
              currentPath: currentPath,
            ),
          );
        }
      }
    }

    return ScanProgress(
      processed: processed,
      total: processed,
    );
  }

  static bool defaultFileFilter(String path) {
    final basename = p.basename(path);
    return !basename.startsWith('.') &&
        !basename.startsWith('.~') &&
        !basename.startsWith('.#');
  }
}
