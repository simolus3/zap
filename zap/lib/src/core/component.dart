import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';

import 'fragment.dart';

abstract class ComponentOrPending {
  void onMount(Function() callback);
  void onDestroy(Function() callback);
  void beforeUpdate(Function() callback);
  void afterUpdate(Function() callback);

  /// A future completing after pending state changes have been applied.
  ///
  /// If no state changes are scheduled, the returned future returns in a new
  /// microtask.
  Future<void> get tick;
}

abstract class ZapComponent implements ComponentOrPending, Fragment {
  static const _updateAll = 0xffffffff;

  final _subscriptions = <StreamSubscription>[];

  final _onMountListeners = <Function>[];
  final _beforeUpdateListeners = <Function()>[];
  final _afterUpdateListeners = <Function()>[];
  final _unmountListeners = <Function()>[];

  var _isAlive = false;

  int _updateBitmask = 0;
  final Map<Fragment, int> _fragmentUpdates = {};
  Completer<void>? _scheduledUpdate;

  ZapComponent();

  @protected
  ComponentOrPending get self => this;

  @override
  void onMount(Function() callback) {
    throw StateError('onMount() may only be called before a component is '
        'initialized!');
  }

  @override
  void onDestroy(Function() callback) => _unmountListeners.add(callback);

  @override
  void beforeUpdate(Function() callback) {
    _beforeUpdateListeners.add(callback);
  }

  @override
  void afterUpdate(Function() callback) {
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

  @protected
  void takeOverPending(PendingComponent component) {
    component._wasCreated = true;

    _onMountListeners.addAll(component._onMount);
    _afterUpdateListeners.addAll(component._onAfterUpdate);
    _beforeUpdateListeners.addAll(component._onBeforeUpdate);
    _unmountListeners.addAll(component._onDestroy);
  }

  void mountTo(Element parent, [Node? anchor]) {
    create();
    mount(parent, anchor);
  }

  @override
  void create() {
    _isAlive = true;
    createInternal();
    _runUpdate(_updateAll);
  }

  @visibleForOverriding
  void createInternal();

  @override
  void mount(Element target, [Node? anchor]) {
    for (final listener in _onMountListeners) {
      final result = listener();
      if (result is Function()) {
        onDestroy(result);
      }
    }

    mountInternal(target, anchor);
  }

  @visibleForOverriding
  void mountInternal(Element target, [Node? anchor]);

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
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final callback in _unmountListeners) {
      callback();
    }

    remove();
  }

  @protected
  void $manageSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
    subscription.onDone(() {
      if (_isAlive) _subscriptions.remove(subscription);
    });
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
}

class PendingComponent extends ComponentOrPending {
  final _onMount = <void Function()>[];
  final _onAfterUpdate = <void Function()>[];
  final _onBeforeUpdate = <void Function()>[];
  final _onDestroy = <void Function()>[];

  var _wasCreated = false;

  @override
  void afterUpdate(Function() callback) {
    _checkNotCreated();
    _onAfterUpdate.add(callback);
  }

  @override
  void beforeUpdate(Function() callback) {
    _checkNotCreated();
    _onBeforeUpdate.add(callback);
  }

  @override
  void onDestroy(Function() callback) {
    _checkNotCreated();
    _onDestroy.add(callback);
  }

  @override
  void onMount(Function() callback) {
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
