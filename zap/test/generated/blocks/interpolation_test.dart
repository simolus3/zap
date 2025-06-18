@Tags(['browser'])
library;

import 'dart:html';

import 'package:test/test.dart';
import 'package:zap/zap.dart';

import 'interpolation.zap.dart';

void main() {
  test('string interpolation', () async {
    final testbed = Element.div();
    final component = Interpolation(ZapValue('test'))..create(testbed);

    expect(testbed.text, 'interpolated=test, wrapped=test, isNull=false');

    component.val = 'updated';
    await component.tick;
    expect(testbed.text, 'interpolated=updated, wrapped=updated, isNull=false');

    component.val = null;
    await component.tick;
    expect(testbed.text, 'interpolated=null, wrapped=null, isNull=true');
  });
}
