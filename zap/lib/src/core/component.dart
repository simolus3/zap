import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';

import 'context.dart';
import 'fragment.dart';
import 'internal.dart';
import 'watchable.dart';

@internal
ZapComponent? parentComponent;

abstract class ComponentOrPending {
  Map<Object?, Object?> get context;

  void onMount(Object? Function() callback);
  void onDestroy(void Function() callback);
  void beforeUpdate(void Function() callback);
  void afterUpdate(void Function() callback);

  /// Emits, or forwards, a custom or DOM event.
  void emitEvent(Event event);

  /// A future completing after pending state changes have been applied.
  ///
  /// If no state changes are scheduled, the returned future returns in a new
  /// microtask.
  Future<void> get tick;
}

extension EmitCustomEvent on ComponentOrPending {
  void emitCustom(String type, [Object? detail]) {
    emitEvent(CustomEvent(type, detail: detail));
  }
}

abstract class ZapComponent implements ComponentOrPending, Fragment {
  final _onMountListeners = <Object? Function()>[];
  final _beforeUpdateListeners = <void Function()>[];
  final _afterUpdateListeners = <void Function()>[];
  final _unmountListeners = <void Function()>[];

  var _isAlive = false;
  var _isRunningUpdate = false;

  int _updateBitmask = 0;
  final Map<Fragment, int> _fragmentUpdates = {};
  Completer<void>? _scheduledUpdate;

  /// A tracker for values `watch()`-ed by this component.
  ///
  /// The generator will assign a unique integer ID to each syntactic occurence
  /// of `watch()` somewhere in the component's code.
  /// Further, calls to `watch()` are translated to calls to [$watchImpl], which
  /// takes this generated ID.
  /// We store IDs we've already subscribed to to avoid creating multiple
  /// subscriptions all the time, as [$watchImpl] is called every time the
  /// current value of a `watch()` call is referenced.
  final Set<int> _activeWatchables = {};

  late final ContextScope _scope;
  final StreamController<Event> _eventEmitter = StreamController.broadcast();

  @override
  Map<Object?, Object?> get context => _scope;

  ZapComponent() {
    _scope = ContextScope(parentComponent?._scope);
  }

  /// Returns a stream transformer binding streams to the lifecycle of this
  /// component.
  ///
  /// Transformed streams will start emitting items as soon as this component
  /// is mounted, and they will dispose when this component is destroyed.
  StreamTransformer<T, T> lifecycle<T>() => _LifecycleTransformer(this);

  @protected
  ComponentOrPending get self => this;

  @internal
  Stream<T> componentEvents<T extends Event>(String type) {
    return _eventEmitter.stream.where((e) => e is T && e.type == type).cast();
  }

  @override
  void onMount(void Function() callback) {
    if (_isAlive) {
      throw StateError('onMount() may only be called before a component is '
          'initialized!');
    }

    _onMountListeners.add(callback);
  }

  @override
  void onDestroy(void Function() callback) => _unmountListeners.add(callback);

  @override
  void beforeUpdate(void Function() callback) {
    _beforeUpdateListeners.add(callback);
  }

  @override
  void afterUpdate(void Function() callback) {
    _afterUpdateListeners.add(callback);
  }

  @override
  Future<void> get tick {
    final scheduled = _scheduledUpdate;

    if (scheduled != null) {
      return scheduled.future;
    } else {
      return Future.microtask(() => null);
    }
  }

  @override
  void emitEvent(Event event) {
    _eventEmitter.add(event);
  }

  @protected
  void forwardEvents(Stream<Event> stream) {
    // Note: Not using `stream.transform(lifecycle())` since we don't know the
    // exact type of stream we're having here.
    lifecycle<Event>().bind(stream).listen(emitEvent);
  }

  @override
  void create(Element target, [Node? anchor]) {
    _isAlive = true;

    for (final listener in _onMountListeners) {
      final result = listener();
      if (result is Object? Function()) {
        onDestroy(result);
      }
    }

    createInternal(target, anchor);
    _runUpdate(updateAll);
  }

  @visibleForOverriding
  void createInternal(Element target, [Node? anchor]);

  void _runUpdate(int delta) {
    for (final before in _beforeUpdateListeners) {
      before();
    }

    update(delta);
    _fragmentUpdates.forEach((fragment, flag) => fragment.update(flag));

    for (final after in _afterUpdateListeners) {
      after();
    }
  }

  @visibleForOverriding
  void remove();

  @override
  void destroy() {
    _isAlive = false;
    for (final callback in _unmountListeners) {
      callback();
    }
    _eventEmitter.close();

    remove();
  }

  void _invalidate(
      {required void Function() set, required void Function() add}) {
    if (!_isAlive) return;

    if (_isRunningUpdate) {
      // Don't schedule an update while another update is running, let's wait
      // first.
      tick.then((_) => _invalidate(set: set, add: add));
      return;
    }

    final scheduled = _scheduledUpdate;

    if (scheduled == null) {
      // No update scheduled yet, do that now!
      set();
      final completer = _scheduledUpdate = Completer.sync();

      scheduleMicrotask(() {
        _scheduledUpdate = null;

        try {
          _isRunningUpdate = true;
          _runUpdate(_updateBitmask);
        } finally {
          _isRunningUpdate = false;
          _updateBitmask = 0;
          _fragmentUpdates.clear();

          completer.complete();
        }
      });
    } else {
      // An update has been scheduled already. Let's just join that one!
      add();
    }
  }

  @protected
  void $invalidate(int flags) {
    _invalidate(
        set: () => _updateBitmask = flags, add: () => _updateBitmask |= flags);
  }

  @protected
  void $invalidateSubcomponent(Fragment fragment, int delta) {
    _invalidate(
      set: () => _fragmentUpdates[fragment] = delta,
      add: () => _fragmentUpdates.update(
        fragment,
        (value) => value | delta,
        ifAbsent: () => delta,
      ),
    );
  }

  @protected
  T $invalidateAssign<T>(int flags, T value) {
    $invalidate(flags);
    return value;
  }

  @protected
  T $invalidateAssignSubcomponent<T>(Fragment f, int flags, T value) {
    $invalidateSubcomponent(f, flags);
    return value;
  }

  @protected
  T $createChildComponent<T extends Fragment>(T Function() create) {
    parentComponent = this;
    final component = create();
    parentComponent = null;

    return component;
  }

  T $watchImpl<T>(
    Watchable<T> watchable,
    int updateFlag, {
    bool sourceIsMutable = false,
  }) {
    if (!sourceIsMutable) {
      if (_activeWatchables.add(updateFlag)) {
        watchable.transform(lifecycle<T>()).listen((event) {
          // Rebuild parts of the component depending on this watchable.
          $invalidate(updateFlag);
        });
      }

      return watchable.value;
    }

    throw UnimplementedError(
        'todo: watch() with a source that could change is not yet supported');
  }
}

class _LifecycleTransformer<T> extends StreamTransformerBase<T, T> {
  final ZapComponent component;

  _LifecycleTransformer(this.component);

  @override
  Stream<T> bind(Stream<T> stream) {
    return Stream.multi(
      (listener) {
        StreamSubscription<T>? subscription;

        void unmountListener() {
          subscription?.cancel();
        }

        void listenNow() {
          subscription = stream.listen(
            listener.addSync,
            onError: listener.addErrorSync,
            onDone: () {
              component._unmountListeners.remove(unmountListener);
              subscription = null;
              listener.closeSync();
            },
          );

          component._unmountListeners.add(unmountListener);
        }

        if (component._isAlive) {
          listenNow();
        } else {
          component.onMount(listenNow);
        }
      },
      isBroadcast: stream.isBroadcast,
    );
  }
}
