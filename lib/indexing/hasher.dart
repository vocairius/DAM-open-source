import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import '../model/cancel_token.dart';

/// Hash SHA-256 de un archivo, calculado en solo lectura y por streaming.
class FileHasher {
  Future<String> sha256(String path, {CancelToken? cancelToken}) async {
    final digest = _DigestSink();
    final input = crypto.sha256.startChunkedConversion(digest);
    final stream = StreamIterator<List<int>>(File(path).openRead());
    try {
      while (await stream.moveNext()) {
        if (cancelToken?.isCancelled ?? false) {
          throw const IndexingCancelledException();
        }
        input.add(stream.current);
      }
      if (cancelToken?.isCancelled ?? false) {
        throw const IndexingCancelledException();
      }
      input.close();
      return digest.events.single.toString();
    } finally {
      await stream.cancel();
    }
  }

  Future<String> sha256Streaming(String path, {CancelToken? cancelToken}) =>
      sha256(path, cancelToken: cancelToken);
}

class _DigestSink implements Sink<crypto.Digest> {
  final events = <crypto.Digest>[];

  @override
  void add(crypto.Digest value) => events.add(value);

  @override
  void close() {}
}
