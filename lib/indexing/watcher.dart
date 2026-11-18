import 'dart:async';
import 'dart:io';

class FsEvent {
  final int type;
  final String path;

  const FsEvent(this.type, this.path);

  @override
  String toString() => '$type: $path';
}

class FolderWatcher {
  final String path;
  final StreamController<FsEvent> _controller =
      StreamController<FsEvent>.broadcast();
  StreamSubscription<FileSystemEvent>? _subscription;

  FolderWatcher(this.path);

  Stream<FsEvent> get events => _controller.stream;

  Future<void> start() async {
    if (_subscription != null) {
      throw StateError('Watched folder is already running: $path');
    }

    final dir = Directory(path);
    if (!await dir.exists()) {
      throw FileSystemException('Watched folder does not exist', path);
    }

    _subscription = dir.watch(recursive: true).listen(
      (event) {
        if (!_controller.isClosed) {
          _controller.add(FsEvent(event.type, event.path));
        }
      },
      onError: _controller.addError,
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
