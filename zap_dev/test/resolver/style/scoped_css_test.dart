import 'package:test/test.dart';
import 'package:zap_dev/src/resolver/style/scoped_css.dart';

void main() {
  test('adds class names to selectors', () {
    final result = componentScss(
        '''
@use 'test';

h1 {
  a {
    color: blue;
  }
}
''',
        'test-scoped',
        []);

    expect(result, '''
@use 'test';

h1.test-scoped{
  a.test-scoped{
    color: blue;
  }
}

''');
  });

  test('does not add a second class for pseudo-selectors', () {
    final result = componentScss(
        '''
h1:nth-child(2n) {
  color: blue;
}
''',
        'test-scoped',
        []);

    expect(result, '''
h1.test-scoped:nth-child(2n){
  color: blue;
}

''');
  });

  test('transforms multiple selectors', () {
    final result = componentScss(
        '''
h1, h2, h3 {
  color: blue;
}
''',
        'test-scoped',
        []);

    expect(result, '''
h1.test-scoped, h2.test-scoped, h3.test-scoped{
  color: blue;
}

''');
  });
}
