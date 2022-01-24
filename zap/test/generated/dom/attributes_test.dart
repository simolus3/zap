@Tags(['browser'])
import 'dart:html';

import 'package:test/test.dart';

import 'attributes.zap.dart';

void main() {
  test('keeps the scoped-css tag when setting the class attribute', () async {
    final testbed = Element.div();
    final component = Attributes(null, null, null)..create(testbed);

    final span = testbed.querySelector('span')!;
    expect(span.classes, containsAll(<Object>[startsWith('zap-'), 'a']));

    component.classes = 'b';
    await component.tick;

    expect(span.classes, containsAll(<Object>[startsWith('zap-'), 'b']));
  });

  test('adds and removes attribute based on boolean', () async {
    final testbed = Element.div();
    final component = Attributes(null, null, null)..create(testbed);

    final span = testbed.querySelector('input')!;
    expect(span.hasAttribute('disabled'), isFalse);

    component.enabled = false;
    await component.tick;

    expect(span.hasAttribute('disabled'), isTrue);
  });

  test('sets or removed nullable attribute', () async {
    final testbed = Element.div();
    final component = Attributes(null, null, null)..create(testbed);

    final span = testbed.querySelector('input')!;
    expect(span.hasAttribute('x-another'), isFalse);

    component.another = 'custom attribute value';
    await component.tick;

    expect(span.attributes['x-another'], 'custom attribute value');
  });
}
