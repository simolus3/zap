import 'dart:html';
import 'dart:math';

import '../core/fragment.dart';
import '../core/internal.dart';

typedef CreateEachFragment<T> = Fragment Function(T element, int index);
typedef UpdateEachFragment<T> = void Function(Fragment f, T element, int index);

/// Implementation for an `for` block in zap.
class ForBlock<T> extends Fragment {
  final CreateEachFragment<T> _create;
  final UpdateEachFragment<T> _update;

  List<T>? _pendingUpdate;
  List<T> _data = [];
  final List<Fragment> _managedFragments = [];
  final _startAnchor = Comment();

  Element? _mountParent;
  Node? _end;

  ForBlock(this._create, this._update);

  void _applyPendingUpdateIfMounted() {
    final parent = _mountParent;
    final pending = _pendingUpdate;

    if (parent != null && pending != null) {
      // Update region present in both lists
      for (var i = 0; i < min(pending.length, _data.length); i++) {
        _update(_managedFragments[i], pending[i], i);
      }

      if (pending.length < _data.length) {
        // Remove superfluous fragments
        for (var i = pending.length; i < _data.length; i++) {
          _managedFragments[i].destroy();
        }
        _managedFragments.removeRange(pending.length, _data.length);
      } else if (pending.length > _data.length) {
        // We need to add additional fragments
        final additionalItems = pending.length - _data.length;
        for (var i = 0; i < additionalItems; i++) {
          final indexInData = i + _data.length;
          final fragment = _create(pending[indexInData], indexInData);

          // Insert fragment at the end.
          _managedFragments.add(fragment);
          fragment.create(parent, _end);
          // Trigger the update action writing the values into the DOM tree.
          fragment.update(updateAll);
        }
      }

      _pendingUpdate = null;
      _data = pending;
    }
  }

  set data(Iterable<T> data) {
    _pendingUpdate = data.toList();
    _applyPendingUpdateIfMounted();
  }

  @override
  void create(Element target, [Node? anchor]) {
    _mountParent = target;
    _end = anchor;
    target.insertBefore(_startAnchor, anchor);
    _applyPendingUpdateIfMounted();
  }

  @override
  void update(int delta) {
    for (final fragment in _managedFragments) {
      fragment.update(delta);
    }
  }

  @override
  void destroy() {
    _mountParent = null;

    _startAnchor.remove();
    for (final fragment in _managedFragments) {
      fragment.destroy();
    }
  }
}
