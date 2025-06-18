@Tags(['browser'])
library;

import 'dart:html';

import 'package:test/test.dart';

import 'assign.zap.dart';
import 'multi.zap.dart';

void main() {
  test('uses default content', () {
    final testbed = Element.div();
    Multi(null, null).create(testbed);

    expect(
      testbed.innerHtml,
      allOf(
        contains('No header was provided'),
        contains('<p>Some content between header and footer</p>'),
      ),
    );
  });

  test('can assign slots', () {
    final testbed = Element.div();
    Assign().create(testbed);

    expect(
      testbed.innerHtml,
      allOf(
        contains('Assigned header'),
        contains('<p>Some content between header and footer</p>'),
        contains('Assigned footer'),
      ),
    );
  });
}
