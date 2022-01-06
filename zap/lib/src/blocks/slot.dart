import 'dart:html';

import '../core/fragment.dart';

/// Implementation of a `<slot>` tag mounted inside of a component.
class Slot extends Fragment {
  final Fragment Function() _create;
  late final Fragment _fragment;

  Slot(this._create);

  @override
  void create(Element target, [Node? anchor]) {
    _fragment = _create()..create(target, anchor);
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
