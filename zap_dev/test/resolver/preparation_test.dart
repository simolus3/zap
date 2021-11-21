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

    expect(result.temporaryDartFile, '''

void __zap___component() {

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

    expect(result.temporaryDartFile, '''

  import 'dart:convert';
void __zap___component() {


  dynamic x;

  void update() {
    x = json.decode('');
  }

}
''');
  });
}
