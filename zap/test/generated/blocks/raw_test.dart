@Tags(['browser'])
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:web/web.dart';
import 'package:zap/zap.dart';

import 'raw.zap.dart';

void main() {
  test('@html works with simple text', () {
    final testbed = HTMLDivElement();
    Raw(ZapValue('simple text')).create(testbed);

    expect(testbed.textContent, 'simple text');
  });

  test('@html can use html tags', () {
    final testbed = HTMLDivElement();
    Raw(ZapValue('<a href="https://github.com">GitHub</a>')).create(testbed);

    expect(testbed.textContent, 'GitHub');
    expect(testbed.children.length, equals(1));
    final anchor = testbed.children.item(0);
    expect(anchor.isA<HTMLAnchorElement>(), isTrue);
    expect((anchor as HTMLAnchorElement).href, equals('https://github.com/'));
  });
}
