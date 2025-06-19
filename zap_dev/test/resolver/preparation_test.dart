import 'package:test/test.dart';
import 'package:zap_dev/src/errors.dart';
import 'package:zap_dev/src/resolver/preparation.dart';

void main() {
  test('generates a Dart script to analyze later', () async {
    final result = await prepare(
      '''
<script>
  var name = 'world';

  void update() {
    name = 'Zap';
  }
</script>

<h1 on:click={update}>Hello {name}!</h1>

''',
      Uri.parse('package:foo/bar.zap'),
      ErrorReporter((error) => fail('Unexpected error: $error')),
    );

    expect(result.script, isNotNull);
    expect(result.style, isNull);

    expect(result.temporaryDartFile.contents, '''
import 'package:web/web.dart';
import 'package:zap/internal/dsl.dart';

void __zap___component(ComponentOrPending self) {

  var name = 'world';

  void update() {
    name = 'Zap';
  }

final __zap__0 = update;
final __zap__1 = name;
}
''');
  });

  test('places imports correctly', () async {
    final result = await prepare(
      '''
<script>
  import 'dart:convert';

  dynamic x;

  void update() {
    x = json.decode('');
  }
</script>

<p>Hi!</p>
''',
      Uri.parse('package:foo/bar.zap'),
      ErrorReporter((error) => fail('Unexpected error: $error')),
    );

    expect(result.script, isNotNull);
    expect(result.style, isNull);

    expect(result.temporaryDartFile.contents, '''
import 'package:web/web.dart';
import 'package:zap/internal/dsl.dart';
import 'dart:convert';
void __zap___component(ComponentOrPending self) {


  dynamic x;

  void update() {
    x = json.decode('');
  }

}
''');
  });
}
