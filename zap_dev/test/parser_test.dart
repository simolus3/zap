import 'package:test/test.dart';
import 'package:zap_dev/src/errors.dart';
import 'package:zap_dev/zap_dev.dart';

void _unexpected(ZapError error) {
  fail('Unexpected error: $error');
}

void main() {
  group('parses if statement', () {
    test('without else', () {
      final component = Parser(
        '''
{#if answer == 42}
	<p>what was the question?</p>
{/if}''',
        Uri.parse('package:a/foo.zap'),
        ErrorReporter(_unexpected),
      ).parse();

      expect(
        component,
        isA<IfStatement>()
            .having(
                (p) => p.condition.dartExpression, 'condition', 'answer == 42')
            .having((p) => p.then, 'then', isNotNull)
            .having((p) => p.otherwise, 'otherwise', isNull),
      );
    });

    test('with else', () {
      final component = Parser(
        '''
{#if answer == 42}
	<p>what was the question?</p>
{:else}
  <p>what was the answer?</p>
{/if}''',
        Uri.parse('package:a/foo.zap'),
        ErrorReporter(_unexpected),
      ).parse();

      expect(
        component,
        isA<IfStatement>()
            .having(
                (p) => p.condition.dartExpression, 'condition', 'answer == 42')
            .having((p) => p.then, 'then', isNotNull)
            .having((p) => p.otherwise, 'otherwise', isA<AdjacentNodes>()),
      );
    });

    test('with else-if', () {
      final component = Parser(
        '''
{#if answer == 42}
	<p>what was the question?</p>
{:else if answer == 43}
  <p>slightly off</p>
{/if}''',
        Uri.parse('package:a/foo.zap'),
        ErrorReporter(_unexpected),
      ).parse();

      expect(
        component,
        isA<IfStatement>()
            .having(
                (p) => p.condition.dartExpression, 'condition', 'answer == 42')
            .having((p) => p.then, 'then', isNotNull)
            .having(
              (p) => p.otherwise,
              'otherwise',
              isA<IfStatement>()
                  .having((e) => e.condition.dartExpression, 'condition',
                      'answer == 43')
                  .having((e) => e.then, 'then', isNotNull)
                  .having((e) => e.otherwise, 'otherwise', isNull),
            ),
      );
    });

    test('with else-if else', () {
      final component = Parser(
        '''
{#if answer == 42}
	<p>what was the question?</p>
{:else if answer == 43}
  <p>slightly off</p>
{:else}
  <p>not even close</p>
{/if}''',
        Uri.parse('package:a/foo.zap'),
        ErrorReporter(_unexpected),
      ).parse();

      expect(
        component,
        isA<IfStatement>()
            .having(
                (p) => p.condition.dartExpression, 'condition', 'answer == 42')
            .having((p) => p.then, 'then', isNotNull)
            .having(
              (p) => p.otherwise,
              'otherwise',
              isA<IfStatement>()
                  .having((e) => e.condition.dartExpression, 'condition',
                      'answer == 43')
                  .having((e) => e.then, 'then', isNotNull)
                  .having((e) => e.otherwise, 'otherwise', isNotNull),
            ),
      );
    });
  });
}
