import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault_dam/database/app_database.dart';
import 'package:vault_dam/indexing/hasher.dart';
import 'package:vault_dam/indexing/indexer.dart';
import 'package:vault_dam/indexing/scanner.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('vault-dam-index-');
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('hashes synthetic files incrementally with SHA-256', () async {
    final file = File('${tempDirectory.path}/sample.bin');
    await file.writeAsString('test');

    expect(
      await FileHasher().sha256(file.path),
      '9f86d081884c7d659a2feaa0c55ad015'
      'a3bf4f1b2b0b822cd15d6c15b0f00a08',
    );
    expect(await file.readAsString(), 'test');
  });

  test('stops hashing when cancelled and leaves the source untouched',
      () async {
    final file = File('${tempDirectory.path}/cancelled.zip');
    const contents = 'synthetic archive bytes';
    await file.writeAsString(contents);
    final cancellation = CancelToken()..cancel();

    await expectLater(
      FileHasher().sha256(file.path, cancelToken: cancellation),
      throwsA(isA<IndexingCancelledException>()),
    );
    expect(await file.readAsString(), contents);
  });

  test('scans asynchronously, filters hidden entries, and can cancel',
      () async {
    final root = Directory('${tempDirectory.path}/scan')..createSync();
    await File('${root.path}/visible.mov').writeAsString('video');
    await File('${root.path}/.hidden').writeAsString('hidden');
    final hiddenDirectory = Directory('${root.path}/.cache')..createSync();
    await File('${hiddenDirectory.path}/ignored.png').writeAsString('hidden');

    final progress = <ScanProgress>[];
    final result = await DirectoryScanner().scan(
      root: root.path,
      cancelToken: CancelToken(),
      onProgress: (item) async => progress.add(item),
    );
    expect(result.processed, 1);
    expect(result.total, 1);
    expect(progress.single.total, isNull);
    expect(progress.single.currentPath, endsWith('visible.mov'));

    final cancellation = CancelToken();
    final cancelled = await DirectoryScanner().scan(
      root: root.path,
      cancelToken: cancellation,
      fileFilter: (_) => true,
      onProgress: (item) async {
        if (item.processed == 1) cancellation.cancel();
      },
    );
    expect(cancelled.cancelled, isTrue);
    expect(cancelled.processed, 1);
  });

  test('indexes and refreshes records without changing originals', () async {
    final root = Directory('${tempDirectory.path}/media')..createSync();
    final file = File('${root.path}/clip.MOV');
    const bytes = 'synthetic video bytes';
    await file.writeAsString(bytes);
    final appDatabase =
        AppDatabase('${tempDirectory.path}/metadata/library.db');
    addTearDown(appDatabase.close);
    final indexer = Indexer(appDatabase);

    final first = await indexer.indexFile(file.path);
    final db = await appDatabase.open();
    await db.update(
      'assets',
      {'notes': 'keep this note'},
      where: 'path = ?',
      whereArgs: [first.path],
    );
    final refreshed = await indexer.indexFile(file.path);
    final duplicate = File('${root.path}/copy.mov');
    await duplicate.writeAsString(bytes);
    await indexer.indexFile(duplicate.path);

    final rows = await db.query('assets', orderBy: 'path');
    expect(rows, hasLength(2));
    expect(rows.first['type'], 'video');
    expect(rows.first['notes'], 'keep this note');
    expect(rows.first['hash'], refreshed.hash);
    expect(rows.last['hash'], refreshed.hash);
    expect(await file.readAsString(), bytes);
    expect(await indexer.listAssets(), hasLength(2));
  });

  test('indexDirectory reports progress and indexes only synthetic files',
      () async {
    final root = Directory('${tempDirectory.path}/batch')..createSync();
    await File('${root.path}/one.wav').writeAsBytes(utf8.encode('audio one'));
    await File('${root.path}/two.pdf').writeAsBytes(utf8.encode('document'));
    final appDatabase = AppDatabase('${tempDirectory.path}/metadata/batch.db');
    addTearDown(appDatabase.close);
    final progress = <ScanProgress>[];

    final result = await Indexer(appDatabase).indexDirectory(
      root: root.path,
      cancelToken: CancelToken(),
      onProgress: (item) async => progress.add(item),
    );

    expect(result.processed, 2);
    expect(progress, hasLength(2));
    final db = await appDatabase.open();
    expect(await db.query('assets'), hasLength(2));
    await appDatabase.close();
  });

  test('throws when the scan root is missing', () async {
    await expectLater(
      DirectoryScanner().scan(
        root: '${tempDirectory.path}/missing',
        cancelToken: CancelToken(),
        onProgress: (_) async {},
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
