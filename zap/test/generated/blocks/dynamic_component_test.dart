@Tags(['browser'])
library;

import 'dart:html';

import 'package:test/test.dart';
import 'package:zap/zap.dart';

import 'dynamic_component.zap.dart' as gen;

void main() {
  test('renders subcomponents', () async {
    final testbed = Element.div();
    final originalChild = _FakeComponent();
    final nextChild = _FakeComponent();

    final component = gen.DynamicComponent(ZapValue(originalChild));
    expect(originalChild._isCreated, isFalse);

    component.create(testbed);
    expect(originalChild._isCreated, isTrue);
    expect(testbed.text, '_FakeComponent');

    // Swapping components should destroy the first one.
    component.component = nextChild;
    await component.tick;
    expect(nextChild._isCreated, isTrue);
    expect(originalChild._removeCalled, isTrue);

    component.destroy();
    expect(nextChild._removeCalled, isTrue);
  });
}

class _FakeComponent extends ZapComponent {
  var _removeCalled = false;
  var _isCreated = false;

  final Text _text = Text('_FakeComponent');

  _FakeComponent() : super();

  @override
  void createInternal(Element target, [Node? anchor]) {
    if (_isCreated) {
      fail('created multiple times');
    }
    _isCreated = true;

    target.insertBefore(_text, anchor);
  }

  @override
  void remove() {
    if (!_isCreated) {
      fail('not created yet, cannot remove');
    }
    if (_removeCalled) {
      fail('already remoevd');
    }

    _removeCalled = true;
  }

  @override
  void update(int delta) {}
}
