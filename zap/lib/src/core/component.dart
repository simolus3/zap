import 'dart:async';
import 'dart:developer';
import 'dart:html';

import 'package:meta/meta.dart';

import 'context.dart';
import 'fragment.dart';
import 'internal.dart';

ContextScope? _parentScope;

abstract class ComponentOrPending {
  Map<Object?, Object?> get context;

  void onMount(Object? Function() callback);
  void onDestroy(void Function() callback);
  void beforeUpdate(void Function() callback);
  void afterUpdate(void Function() callback);

  /// A future completing after pending state changes have been applied.
  ///
  /// If no state changes are scheduled, the returned future returns in a new
  /// microtask.
  Future<void> get tick;
}

abstract class ZapComponent implements ComponentOrPending, Fragment {
  final _onMountListeners = <Object? Function()>[];
  final _beforeUpdateListeners = <void Function()>[];
  final _afterUpdateListeners = <void Function()>[];
  final _unmountListeners = <void Function()>[];

  var _isAlive = false;

  int _updateBitmask = 0;
  final Map<Fragment, int> _fragmentUpdates = {};
  Completer<void>? _scheduledUpdate;

  final ContextScope _scope;

  @override
  Map<Object?, Object?> get context => _scope;

  ZapComponent(PendingComponent pendingSelf) : _scope = pendingSelf._context {
    pendingSelf._wasCreated = true;

    _onMountListeners.addAll(pendingSelf._onMount);
    _afterUpdateListeners.addAll(pendingSelf._onAfterUpdate);
    _beforeUpdateListeners.addAll(pendingSelf._onBeforeUpdate);
    _unmountListeners.addAll(pendingSelf._onDestroy);
  }

  /// Returns a stream transformer binding streams to the lifecycle of this
  /// component.
  ///
  /// Transformed streams will start emitting items as soon as this component
  /// is mounted, and they will dispose when this component is destroyed.
  StreamTransformer<T, T> lifecycle<T>() => _LifecycleTransformer(this);

  @protected
  ComponentOrPending get self => this;

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
    _fragmentUpdates.clear();

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

    remove();
  }

  @protected
  void $invalidate(int flags) {
    if (!_isAlive) return;

    final scheduled = _scheduledUpdate;

    if (scheduled == null) {
      // No update scheduled yet, do that now!
      _updateBitmask = flags;
      final completer = _scheduledUpdate = Completer.sync();

      scheduleMicrotask(() {
        _scheduledUpdate = null;

        try {
          _runUpdate(_updateBitmask);
        } finally {
          completer.complete();
        }
      });
    } else {
      // An update has been scheduled already. Let's just join that one!
      _updateBitmask |= flags;
    }
  }

  @protected
  void $invalidateSubcomponent(Fragment fragment, int delta) {
    final scheduled = _scheduledUpdate;

    if (scheduled == null) {
      // No update scheduled yet, do that now!
      _fragmentUpdates[fragment] = delta;
      final completer = _scheduledUpdate = Completer.sync();

      scheduleMicrotask(() {
        _scheduledUpdate = null;

        try {
          _runUpdate(_updateBitmask);
        } finally {
          completer.complete();
        }
      });
    } else {
      // An update has been scheduled already. Let's just join that one!
      _fragmentUpdates.update(
        fragment,
        (value) => value | delta,
        ifAbsent: () => delta,
      );
    }
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
  T $createChildComponent<T extends ZapComponent>(T Function() create) {
    _parentScope = _scope;
    final component = create();
    _parentScope = null;

    return component;
  }
}

class PendingComponent extends ComponentOrPending {
  final _onMount = <void Function()>[];
  final _onAfterUpdate = <void Function()>[];
  final _onBeforeUpdate = <void Function()>[];
  final _onDestroy = <void Function()>[];

  var _wasCreated = false;

  final _context = ContextScope(_parentScope);

  @override
  Map<Object?, Object?> get context => _context;

  @override
  void afterUpdate(void Function() callback) {
    _checkNotCreated();
    _onAfterUpdate.add(callback);
  }

  @override
  void beforeUpdate(void Function() callback) {
    _checkNotCreated();
    _onBeforeUpdate.add(callback);
  }

  @override
  void onDestroy(void Function() callback) {
    _checkNotCreated();
    _onDestroy.add(callback);
  }

  @override
  void onMount(void Function() callback) {
    _checkNotCreated();
    _onMount.add(callback);
  }

  @override
  Future<void> get tick => Future.microtask(() => null);

  void _checkNotCreated() {
    if (_wasCreated) {
      throw StateError('Called a runtime component method on an invalid '
          'pending component instance. Are you storing `self` in a variable?');
    }
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
