import 'dart:html';

import '../core/component.dart';
import '../core/fragment.dart';

/// Implementation of a `<slot>` tag mounted inside of a component.
class Slot extends Fragment {
  final Fragment Function() _create;
  final ZapComponent _parent;

  late final Fragment _fragment;

  Slot(this._create, this._parent);

  @override
  void create(Element target, [Node? anchor]) {
    final oldParent = parentComponent;
    // Don't overide the parent component if one is already set. The reason
    // is that slots passed down multiple times are first created from the inner
    // component and then from the outer one. They should inherit their scope
    // from the inner one though.
    if (oldParent == null) {
      parentComponent = _parent;
    }

    _fragment = _create()..create(target, anchor);
    parentComponent = oldParent;
  }

  @override
  void update(int delta) {
    _fragment.update(delta);
  }

  @override
  void destroy() {
    _fragment.destroy();
  }
}
