@Tags(['browser'])
import 'dart:async';
import 'dart:html';

import 'package:test/test.dart';
import 'package:zap/zap.dart';
import 'stream.zap.dart' as gen;

void main() {
  test('single stream', () async {
    final testbed = Element.div();
    final controller = StreamController<String>();
    addTearDown(controller.close);

    final component = gen.Stream(ZapValue(controller.stream));
    expect(controller.hasListener, isFalse,
        reason: 'Instantiating the component should not start a stream '
            'subscription');

    component.create(testbed);
    expect(testbed.innerText, contains('no data / no error'));
    await pumpEventQueue(times: 1);
    expect(controller.hasListener, isTrue);
    expect(testbed.innerText, contains('no data / no error'));

    controller.add('first element');
    await pumpEventQueue(times: 1);
    expect(testbed.innerText, contains('data: first element'));

    controller.addError('first error');
    await pumpEventQueue(times: 1);
    expect(testbed.innerText, contains('error: first error'));

    controller.add('second element');
    await pumpEventQueue(times: 1);
    expect(testbed.innerText, contains('data: second element'));

    component.destroy();
    await pumpEventQueue(times: 1);
    expect(controller.hasListener, isFalse);
  });
}
