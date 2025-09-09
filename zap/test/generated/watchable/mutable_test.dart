@Tags(['browser'])
library;

import 'package:sanitize_dom/sanitize_dom.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';
import 'package:zap/zap.dart';

import 'mutable.zap.dart';

void main() {
  test('updates component when watchable updates its value', () async {
    final watchable = WritableWatchable(0);
    final testbed = HTMLDivElement();

    final component = Mutable(ZapValue(watchable))..create(testbed);
    addTearDown(component.destroy);

    expect(testbed.innerHtml, 'Current value is 0.');

    watchable.value++;
    // Once for the stream, once for the component
    await pumpEventQueue(times: 2);
    expect(testbed.innerHtml, 'Current value is 1.');
  });

  test('updates component when watchable changes', () async {
    final testbed = HTMLDivElement();

    final component = Mutable(ZapValue(WritableWatchable(0)))..create(testbed);
    addTearDown(component.destroy);

    expect(testbed.innerHtml, 'Current value is 0.');

    final watchable = WritableWatchable(1);
    component.watchable = watchable;
    await component.tick;
    expect(testbed.innerHtml, 'Current value is 1.');

    watchable.value++;
    // Once for the stream, once for the component
    await pumpEventQueue(times: 2);
    expect(testbed.innerHtml, 'Current value is 2.');
  });
}
