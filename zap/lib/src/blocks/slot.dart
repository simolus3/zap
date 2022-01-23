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
    parentComponent = _parent;
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
