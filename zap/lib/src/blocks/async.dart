import 'dart:async';
import 'dart:html';

import '../core/fragment.dart';

/// Creates a [Future] based on what the [create] function returns. If [create]
/// throws, the future will complete with the same exception.
///
/// This is used by generated code to guard against evaluating future
/// expressions that throw.
Future<T> $safeFuture<T>(FutureOr<T> Function() create) {
  return Future.sync(create);
}

/// Creates a [Stream] based on what the [create] function returns. If [create]
/// throws, the stream will emit that error and then close.
///
/// This is used by generated code to guard against evaluating stream
/// expressions that throw.
Stream<T> $safeStream<T>(Stream<T> Function() create) {
  try {
    return create();
  } catch (e, s) {
    return Stream.error(e, s);
  }
}

enum _SnapshotState { unresolved, data, error }

class ZapSnapshot<T> {
  final _SnapshotState _state;
  final bool isDone;

  final T? _data;
  final Object? _error;
  final StackTrace? _trace;

  ZapSnapshot._internal(
      this._state, this.isDone, this._data, this._error, this._trace);

  const ZapSnapshot.unresolved()
      : _state = _SnapshotState.unresolved,
        isDone = false,
        _data = null,
        _error = null,
        _trace = null;

  ZapSnapshot._withData(this._data)
      : _state = _SnapshotState.data,
        _error = null,
        _trace = null,
        isDone = false;

  ZapSnapshot._withError(this._error, this._trace)
      : _state = _SnapshotState.error,
        _data = null,
        isDone = false;

  bool get hasData => _state == _SnapshotState.data;
  bool get hasError => _state == _SnapshotState.error;

  T get data {
    if (!hasData) {
      throw StateError('This snapshot does not have data');
    }

    return _data as T;
  }

  Object get error {
    if (!hasError) {
      throw StateError('This snapshot does not have an error');
    }

    return _error!;
  }

  StackTrace? get trace {
    if (!hasError) {
      throw StateError('This snapshot does not have an error');
    }

    return _trace;
  }

  ZapSnapshot<T> get _finished {
    return ZapSnapshot._internal(_state, true, _data, _error, _trace);
  }

  @override
  String toString() {
    switch (_state) {
      case _SnapshotState.unresolved:
        return 'ZapSnapshot (unresolved)';
      case _SnapshotState.data:
        return 'ZapSnapshot (data = $data)';
      case _SnapshotState.error:
        return 'ZapSnapshot (error = $error)';
    }
  }
}

abstract class _AsyncBlockBase<T> extends Fragment {
  final Fragment _fragment;
  final void Function(Fragment, ZapSnapshot<T>) _update;

  _AsyncBlockBase(this._fragment, this._update);

  void _connect();
  void _cleanUp();

  @override
  void create() {
    _update(_fragment, const ZapSnapshot.unresolved());
    _fragment.create();
    _connect();
  }

  @override
  void mount(Element target, [Node? anchor]) {
    _fragment.mount(target, anchor);
  }

  @override
  void update(int delta) {
    _fragment.update(delta);
  }

  @override
  void destroy() {
    _fragment.destroy();
    _cleanUp();
  }
}

class FutureBlock<T> extends _AsyncBlockBase<T> {
  Future<T>? _future;

  FutureBlock(Fragment fragment, void Function(Fragment, ZapSnapshot<T>) update)
      : super(fragment, update);

  set future(FutureOr<T> future) {
    if (future is Future<T>) {
      _update(_fragment, const ZapSnapshot.unresolved());

      future.then(
        (value) => _thenCallback(future, value),
        onError: (Object error, StackTrace trace) =>
            _onErrorCallback(future, error, trace),
      );
      _future = future;
    } else {
      _update(_fragment, ZapSnapshot._withData(future));
    }
  }

  void _thenCallback(Future<T> future, T result) {
    // Only update if the future is still the current future we're interested in
    if (identical(future, _future)) {
      _update(_fragment, ZapSnapshot<T>._withData(result)._finished);
    }
  }

  void _onErrorCallback(Future<T> future, Object error, StackTrace trace) {
    if (identical(future, _future)) {
      _update(_fragment, ZapSnapshot<T>._withError(error, trace)._finished);
    }
  }

  @override
  void _cleanUp() {
    _future = null;
  }

  @override
  void _connect() {}
}

class StreamBlock<T> extends _AsyncBlockBase<T> {
  bool _isReady = false;
  StreamSubscription<T>? _subscription;

  ZapSnapshot<T> _snapshot = const ZapSnapshot.unresolved();

  StreamBlock(Fragment fragment, void Function(Fragment, ZapSnapshot<T>) update)
      : super(fragment, update);

  set stream(Stream<T> stream) {
    _subscription?.cancel();

    // ignore: cancel_subscriptions
    final sub = _subscription = stream.listen(
      (event) => _report(ZapSnapshot._withData(event)),
      onError: (Object e, StackTrace s) =>
          _report(ZapSnapshot._withError(e, s)),
      onDone: () => _update(_fragment, _snapshot._finished),
    );
    if (!_isReady) {
      sub.pause();
    }
  }

  void _report(ZapSnapshot<T> snapshot) {
    _snapshot = snapshot;
    _update(_fragment, snapshot);
  }

  @override
  void _connect() {
    _isReady = true;
    _subscription?.resume();
  }

  @override
  void _cleanUp() {
    _isReady = false;
    _subscription?.cancel();
  }
}
