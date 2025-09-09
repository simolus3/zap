import 'dart:async';

import '../core/snapshot.dart';

/// A specialized stream that
///
///  - never emits errors
///  - always provides the current value through [value].
///
/// These streams can safely be listened to in components by using the `watch`
/// macro in zap components.
abstract class Watchable<T> implements Stream<T> {
  T get value;

  factory Watchable.stream(Stream<T> stream, T initialValue) {
    return _StreamWatchable(_ValueWrappingStream(stream), initialValue);
  }

  static Watchable<ZapSnapshot<T>> snapshots<T>(Stream<T> stream) {
    final snapshots = Stream<ZapSnapshot<T>>.eventTransformed(
      stream,
      _ToSnapshotTransformer.new,
    );

    return _StreamWatchable(
      _ValueWrappingStream(snapshots),
      const ZapSnapshot<Never>.unresolved(),
    );
  }
}

class WritableWatchable<T> extends Stream<T> implements Watchable<T> {
  final List<MultiStreamController<T>> _controllers = [];

  late final Stream<T> _stream;
  T _lastValue;

  WritableWatchable(this._lastValue) {
    _stream = Stream.multi((controller) {
      controller.add(_lastValue);

      void pauseOrStop() {
        _controllers.remove(controller);
      }

      void resume() {
        _controllers.add(controller);
      }

      resume();
      controller
        ..onPause = pauseOrStop
        ..onCancel = pauseOrStop
        ..onResume = resume;
    });
  }

  @override
  T get value => _lastValue;

  set value(T value) {
    _lastValue = value;

    for (final listener in _controllers) {
      listener.add(value);
    }
  }

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(onData, onDone: onDone);
  }
}

class _StreamWatchable<T> extends Stream<T> implements Watchable<T> {
  final _ValueWrappingStream<T> _source;
  final T? _initialValue;

  _StreamWatchable(this._source, this._initialValue);

  @override
  bool get isBroadcast => true;

  @override
  T get value => (_source._hasValue ? _source._lastValue : _initialValue) as T;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // Skipping onError because the source stream isn't supposed to emit errors
    // ever. We want this to be an unhandled error.
    return _source.listen(onData, cancelOnError: cancelOnError, onDone: onDone);
  }
}

class _ToSnapshotTransformer<T> implements EventSink<T> {
  final EventSink<ZapSnapshot<T>> _out;
  ZapSnapshot<T>? _last;

  _ToSnapshotTransformer(this._out);

  @override
  void add(T event) => _out.add(_last = ZapSnapshot.withData(event));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _out.add(_last = ZapSnapshot.withError(error, stackTrace));
  }

  @override
  void close() {
    final last = _last;
    if (last != null) {
      _out.add(last.finished);
    }

    _out.close();
  }
}

class _ValueWrappingStream<T> extends Stream<T> {
  // ignore: close_sinks
  final _controller = StreamController<T>.broadcast();
  var _listeners = 0;

  final Stream<T> _source;
  late final Stream<T> _refCounting;

  StreamSubscription<T>? _subscription;
  T? _lastValue;
  bool _hasValue = false;

  _ValueWrappingStream(this._source) {
    _refCounting = Stream.multi((listener) {
      void resumeOrStart() {
        _listeners++;

        _subscription ??= _source.listen(
          (event) {
            _hasValue = true;
            _lastValue = event;
            _controller.add(event);
          },
          onError: _controller.addError,
          onDone: _controller.close,
        );
      }

      void pauseOrStop() {
        _listeners--;

        if (_listeners == 0) {
          _subscription?.cancel();
          _subscription = null;
        }
      }

      if (_hasValue) {
        listener.add(_lastValue as T);
      }
      listener.addStream(_controller.stream);
      listener
        ..onCancel = pauseOrStop
        ..onPause = pauseOrStop
        ..onResume = resumeOrStart;
      resumeOrStart();
    });
  }

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _refCounting.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
