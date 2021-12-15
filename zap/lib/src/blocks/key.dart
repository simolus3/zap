import 'dart:html';

import '../core/fragment.dart';

/// A `{#key <expression>}` block.
///
/// A key block destroys and re-creates its content when the value of the
/// provided expression changes.
class KeyBlock extends Fragment {
  /// The function creating a new inner fragment when needed.
  final Fragment Function() createInner;

  Object? _value;
  Fragment? _currentFragment;

  Element? _target;
  Node? _anchor;

  KeyBlock(this.createInner);

  /// Sets the value of the evaluated expression backing this key block.
  ///
  /// When it changes, the inner component is destroyed and re-created.
  ///
  /// This function should only be called while this fragment is ready (after
  /// [create] and before [destroy]).
  set value(Object? val) {
    if (_value != val) {
      _value = val;

      _recreateFragment();
    }
  }

  void _recreateFragment() {
    _currentFragment?.destroy();
    final newFragment = _currentFragment = createInner();

    if (_target != null) {
      // This fragment is mounted, so let's also mount the content
      newFragment.create(_target!, _anchor);
    }
  }

  @override
  void create(Element target, [Node? anchor]) {
    _target = target;
    _anchor = anchor;

    if (_currentFragment == null) {
      // Create the initial fragment to show.
      _recreateFragment();
    } else {
      _currentFragment?.create(target, anchor);
    }
  }

  @override
  void update(int delta) {
    _currentFragment?.update(delta);
  }

  @override
  void destroy() {
    _currentFragment?.destroy();
  }
}
