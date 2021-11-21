@Tags(['browser'])
import 'dart:async';
import 'dart:html';

import 'package:test/test.dart';
import 'package:zap/zap.dart';
import 'stream.zap.dart';

void main() {
  test('single stream', () {
    final testbed = Element.div();
    final controller = StreamController<String>();

    final component = stream(ZapValue(controller.stream));
    expect(controller.hasListener, isFalse,
        reason: 'Instantiating the component should not start a stream '
            'subscription');

    component.mountTo(testbed);
    expect(controller.hasListener, isTrue);

    expect(testbed.innerText, '');
  });
}
