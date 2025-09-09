@Tags(['browser'])
library;

import 'package:test/test.dart';
import 'package:web/web.dart';
import 'package:zap/zap.dart';

import 'interpolation.zap.dart';

void main() {
  test('string interpolation', () async {
    final testbed = HTMLDivElement();
    final component = Interpolation(ZapValue('test'))..create(testbed);

    expect(
      testbed.textContent,
      'interpolated=test, wrapped=test, isNull=false',
    );

    component.val = 'updated';
    await component.tick;
    expect(
      testbed.textContent,
      'interpolated=updated, wrapped=updated, isNull=false',
    );

    component.val = null;
    await component.tick;
    expect(testbed.textContent, 'interpolated=null, wrapped=null, isNull=true');
  });
}
