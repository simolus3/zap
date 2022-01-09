import 'dart:html';

import '../core/component.dart';
import '../core/fragment.dart';

/// Implementation of a `<zap:component>` tag that renders a component evaluated
/// dynamically.
class DynamicComponent implements Fragment {
  final Node _anchor = Comment();
  Element? _parent;

  ZapComponent _component;

  DynamicComponent(this._component);

  set component(ZapComponent component) {
    final parent = _parent;
    if (parent != null) {
      // This DynamicComponent has been added to the DOM tree, so destroy the
      // old component and re-create the new one in-place
      _component.destroy();
      _component = component;

      _component.create(parent, _anchor);
    } else {
      // This fragment has never been created, so we don't need to destroy the
      // old component either.
      _component = component;
    }
  }

  @override
  void create(Element target, [Node? anchor]) {
    target.insertBefore(_anchor, anchor);
    _component.create(target, _anchor);

    _parent = target;
  }

  @override
  void destroy() {
    _component.destroy();
  }

  @override
  void update(int delta) {
    _component.update(delta);
  }
}
