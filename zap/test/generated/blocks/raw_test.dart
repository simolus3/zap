@Tags(['browser'])
import 'dart:html';

import 'package:test/test.dart';
import 'package:zap/zap.dart';

import 'raw.zap.dart';

void main() {
  test('@html works with simple text', () {
    final testbed = Element.div();
    Raw(ZapValue('simple text')).create(testbed);

    expect(testbed.text, 'simple text');
  });

  test('@html can use html tags', () {
    final testbed = Element.div();
    Raw(ZapValue('<a href="https://github.com">GitHub</a>')).create(testbed);

    expect(testbed.text, 'GitHub');
    expect(testbed.children, [
      isA<AnchorElement>().having((e) => e.href, 'href', 'https://github.com/')
    ]);
  });
}
