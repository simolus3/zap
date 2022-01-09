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

  ZapSnapshot.withData(this._data)
      : _state = _SnapshotState.data,
        _error = null,
        _trace = null,
        isDone = false;

  ZapSnapshot.withError(this._error, this._trace)
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

  ZapSnapshot<T> get finished {
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
