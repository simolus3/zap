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

.test-scoped h1{
  .test-scoped a{
    color: blue;
  }
}
''');
  });
}
