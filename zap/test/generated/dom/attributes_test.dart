@Tags(['browser'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:web/web.dart';

import 'attributes.zap.dart';

void main() {
  test('keeps the scoped-css tag when setting the class attribute', () async {
    final testbed = HTMLDivElement();
    final component = Attributes(null, null, null)..create(testbed);

    final span = testbed.querySelector('span')!;
    expect(
      span.className.split(' '),
      containsAll(<Object>[startsWith('zap-'), 'a']),
    );

    component.classes = 'b';
    await component.tick;

    expect(
      span.className.split(' '),
      containsAll(<Object>[startsWith('zap-'), 'b']),
    );
  });

  test('adds and removes attribute based on boolean', () async {
    final testbed = HTMLDivElement();
    final component = Attributes(null, null, null)..create(testbed);

    final span = testbed.querySelector('input')!;
    expect(span.hasAttribute('disabled'), isFalse);

    component.enabled = false;
    await component.tick;

    expect(span.hasAttribute('disabled'), isTrue);
  });

  test('sets or removed nullable attribute', () async {
    final testbed = HTMLDivElement();
    final component = Attributes(null, null, null)..create(testbed);

    final span = testbed.querySelector('input')!;
    expect(span.hasAttribute('x-another'), isFalse);

    component.another = 'custom attribute value';
    await component.tick;

    expect(span.getAttribute('x-another'), 'custom attribute value');
  });
}
