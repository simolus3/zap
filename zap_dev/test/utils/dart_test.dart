import 'package:test/test.dart';
import 'package:zap_dev/src/utils/dart.dart';

void main() {
  group('splits imports and body', () {
    test('when there are imports', () {
      final component = ScriptComponents.of('''
import 'dart:async';
import 'package:foo/bar.dart';

void main() {
  print('test');
}
''');

      expect(component.directives,
          "import 'dart:async';import 'package:foo/bar.dart';");
      expect(component.body, '''


void main() {
  print('test');
}
''');
    });

    test('when there are no import', () {
      final component = ScriptComponents.of('''
void main() {
  print('test');
}
''');

      expect(component.directives, isEmpty);
      expect(component.body, '''
void main() {
  print('test');
}
''');
    });
  });

  test('rewrites .zap imports', () {
    final component = ScriptComponents.of('''
import 'test.zap';
import 'package:foo/bar.dart';
import 'package:another/component.zap';

void main() {
  print('test');
}
''');

    expect(
        component.directives,
        "import 'test.tmp.zap.api.dart';"
        "import 'package:foo/bar.dart';"
        "import 'package:another/component.tmp.zap.api.dart';");
    expect(component.body, '''


void main() {
  print('test');
}
''');
  });
}
