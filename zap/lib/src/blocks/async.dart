import 'dart:async';

import 'package:web/web.dart';

import '../core/fragment.dart';
import '../core/snapshot.dart';

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

abstract class _AsyncBlockBase<T> extends Fragment {
  final Fragment _fragment;
  final void Function(Fragment, ZapSnapshot<T>) _update;

  _AsyncBlockBase(this._fragment, this._update);

  void _connect();
  void _cleanUp();

  @override
  void create(Element target, [Node? anchor]) {
    _update(_fragment, const ZapSnapshot.unresolved());
    _connect();

    _fragment.create(target, anchor);
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

  FutureBlock(super.fragment, super.update);

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
      _update(_fragment, ZapSnapshot.withData(future));
    }
  }

  void _thenCallback(Future<T> future, T result) {
    // Only update if the future is still the current future we're interested in
    if (identical(future, _future)) {
      _update(_fragment, ZapSnapshot<T>.withData(result).finished);
    }
  }

  void _onErrorCallback(Future<T> future, Object error, StackTrace trace) {
    if (identical(future, _future)) {
      _update(_fragment, ZapSnapshot<T>.withError(error, trace).finished);
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

  StreamBlock(super.fragment, super.update);

  set stream(Stream<T> stream) {
    _subscription?.cancel();

    // ignore: cancel_subscriptions
    final sub = _subscription = stream.listen(
      (event) => _report(ZapSnapshot.withData(event)),
      onError: (Object e, StackTrace s) => _report(ZapSnapshot.withError(e, s)),
      onDone: () => _update(_fragment, _snapshot.finished),
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
