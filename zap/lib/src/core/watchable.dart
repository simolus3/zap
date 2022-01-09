import 'dart:async';

import 'package:rxdart/rxdart.dart';

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
    return _StreamWatchable(_ToValueStream(stream), initialValue);
  }

  factory Watchable.valueStream(ValueStream<T> stream, [T? initialValue]) {
    if (!stream.hasValue && initialValue is! T) {
      throw ArgumentError(
          'The provided value stream did not have a value right away and no'
          'fallback value has been set.');
    }

    return _StreamWatchable(stream, initialValue);
  }

  static Watchable<ZapSnapshot<T>> snapshots<T>(Stream<T> stream) {
    return valueSnapsots(_ToValueStream(stream));
  }

  static Watchable<ZapSnapshot<T>> valueSnapsots<T>(ValueStream<T> stream) {
    return _SnapshotStreamWatchable(stream);
  }
}

class WritableWatchable<T> extends Stream<T> implements Watchable<T> {
  final BehaviorSubject<T> _subject;

  WritableWatchable(T initial) : _subject = BehaviorSubject.seeded(initial);

  @override
  T get value => _subject.value;

  set value(T value) => _subject.value = value;

  @override
  bool get isBroadcast => _subject.isBroadcast;

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _subject.listen(onData, onDone: onDone);
  }
}

class _StreamWatchable<T> extends Stream<T> implements Watchable<T> {
  final ValueStream<T> _source;
  final T? _initialValue;

  _StreamWatchable(this._source, this._initialValue);

  @override
  bool get isBroadcast => _source.isBroadcast;

  @override
  T get value => _source.hasValue ? _source.value : _initialValue as T;

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    // Skipping onError because the source stream isn't supposed to emit errors
    // ever. We want this to be an unhandled error.
    return _source.listen(onData, cancelOnError: cancelOnError, onDone: onDone);
  }
}

class _SnapshotStreamWatchable<T> extends Stream<ZapSnapshot<T>>
    implements Watchable<ZapSnapshot<T>> {
  final ValueStream<T> _source;
  final Stream<ZapSnapshot<T>> _asSnapshots;

  _SnapshotStreamWatchable(this._source)
      : _asSnapshots = Stream.eventTransformed(
            _source, (sink) => _ToSnapshotTransformer<T>(sink));

  @override
  bool get isBroadcast => _asSnapshots.isBroadcast;

  @override
  ZapSnapshot<T> get value {
    if (_source.hasValue) {
      return ZapSnapshot.withData(_source.value);
    } else if (_source.hasError) {
      return ZapSnapshot.withError(_source.error, _source.stackTrace);
    } else {
      return const ZapSnapshot.unresolved();
    }
  }

  @override
  StreamSubscription<ZapSnapshot<T>> listen(
      void Function(ZapSnapshot<T> event)? onData,
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    // We can ignore onError and cancelOnError here since this stream won't
    // emit errors.
    return _asSnapshots.listen(onData, onDone: onDone);
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

/// A zap variant of `shareValue()` that never closes the underlying behavior
/// subject, so that it really can be listened to multiple times.
///
/// (this is fine, by the way. If there really are no more references, the
/// subject will just be GCed.)
class _ToValueStream<T> extends Stream<T> implements ValueStream<T> {
  // ignore: close_sinks
  final _subject = BehaviorSubject<T>();
  var _listeners = 0;

  final Stream<T> _source;
  late final Stream<T> _refCounting;

  StreamSubscription<T>? _subscription;

  _ToValueStream(this._source) {
    _refCounting = Stream.multi((listener) {
      void resumeOrStart() {
        _listeners++;

        _subscription ??= _source.listen(_subject.add,
            onError: _subject.addError, onDone: _subject.close);
      }

      void pauseOrStop() {
        _listeners--;

        if (_listeners == 0) {
          _subscription?.cancel();
          _subscription = null;
        }
      }

      listener.addStream(_subject);
      listener
        ..onCancel = pauseOrStop
        ..onPause = pauseOrStop
        ..onResume = resumeOrStart;
      resumeOrStart();
    });
  }

  @override
  Object get error => _subject.error;

  @override
  Object? get errorOrNull => _subject.errorOrNull;

  @override
  bool get hasError => _subject.hasError;

  @override
  bool get hasValue => _subject.hasValue;

  @override
  StackTrace? get stackTrace => _subject.stackTrace;

  @override
  T get value => _subject.value;

  @override
  T? get valueOrNull => _subject.valueOrNull;

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _refCounting.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
