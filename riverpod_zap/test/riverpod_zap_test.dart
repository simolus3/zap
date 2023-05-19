import 'dart:html';

import 'package:test/test.dart';
import 'package:zap/zap.dart';

import 'components/default-scope.zap.dart';
import 'components/overrides.zap.dart';

void main() {
  late Element testbed;

  setUp(() => testbed = Element.div());
  tearDown(() => testbed.remove());

  test('creates and listens to simple provider', () {
    final component = DefaultScope()..create(testbed);
    addTearDown(component.destroy);

    expect(testbed.innerHtml, 'The current value is 0.');
  });

/*
  test('disposes containers after the component is destroyed', () {
    expect(RiverpodBinding.debugInstance.containers, isEmpty);

    final component = DefaultScope()..create(testbed);
    expect(RiverpodBinding.debugInstance.containers, isNotEmpty);
    component.destroy();

    expect(RiverpodBinding.debugInstance.containers, isEmpty);
  });
*/

  test('listens to provider overrides', () async {
    final component = Overrides(ZapValue(1))..create(testbed);
    addTearDown(component.destroy);

    expect(testbed.innerHtml, 'The current value is 1.');

    // Passed down to riverpod-scope.overrides, which should in turn update
    // another component.
    component.overriddenValue = 3;
    await pumpEventQueue(times: 1);
    expect(testbed.innerHtml, 'The current value is 3.');
  });
}
