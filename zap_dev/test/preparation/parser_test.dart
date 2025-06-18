import 'package:test/test.dart';
import 'package:zap_dev/src/errors.dart';
import 'package:zap_dev/src/preparation/ast.dart';
import 'package:zap_dev/src/preparation/parser.dart';
import 'package:zap_dev/src/preparation/scanner.dart';

DomNode _parse(String source) {
  final scanner = Scanner(
    source,
    Uri.parse('test:source'),
    ErrorReporter((error) => fail('Unexpected errror $error')),
  );
  return Parser(scanner).parse();
}

void _check(String source, AstNode expected) {
  final result = _parse(source);
  _checkEqual(result, expected);
}

void main() {
  test('parses if statements', () {
    _check(
      '''
{# if dart_expression }
a
{: else   if  another_expression}
b
{:else}
c
{/if}''',
      IfBlock([
        IfCondition(RawDartExpression(' dart_expression '), Text('\na\n')),
        IfCondition(RawDartExpression('another_expression'), Text('\nb\n')),
      ], Text('\nc\n')),
    );
  });

  test('parses simple component', () {
    _check(
      '''
<script>
  @Property()
  var counter = 0;

  void increase() => counter++;
</script>
<button on:click={increase}>
  Clicked {counter} {counter == 1 ? 'time' : 'times' }
</button>''',
      AdjacentNodes([
        Element(
          'script',
          [],
          Text('''

  @Property()
  var counter = 0;

  void increase() => counter++;
'''),
        ),
        Text('\n'),
        Element(
          'button',
          [
            Attribute(
              'on:click',
              DartExpression(RawDartExpression('increase')),
            ),
          ],
          AdjacentNodes([
            Text('\n  Clicked '),
            DartExpression(RawDartExpression('counter')),
            Text(' '),
            DartExpression(
              RawDartExpression("counter == 1 ? 'time' : 'times' "),
            ),
            Text('\n'),
          ]),
        ),
      ]),
    );
  });

  test('parses slots', () {
    _check(
      '''
<div>
  <slot name="header">No header was provided</slot>
  <p>Some content between header and footer</p>
  <slot name="footer"></slot>
</div>''',
      Element(
        'div',
        [],
        AdjacentNodes([
          Text('\n  '),
          Element('slot', [
            Attribute('name', StringLiteral([Text('header')])),
          ], Text('No header was provided')),
          Text('\n  '),
          Element('p', [], Text('Some content between header and footer')),
          Text('\n  '),
          Element('slot', [
            Attribute('name', StringLiteral([Text('footer')])),
          ], AdjacentNodes([])),
          Text('\n'),
        ]),
      ),
    );
  });

  test('parses complex Dart expression', () {
    _check(
      '''
<span on:mousemove={(MouseEvent e) { x = event.client.x; y = event.client.y; }}>
</span>
''',
      AdjacentNodes([
        Element('span', [
          Attribute(
            'on:mousemove',
            DartExpression(
              RawDartExpression(
                '(MouseEvent e) { x = event.client.x; y = event.client.y; }',
              ),
            ),
          ),
        ], Text('\n')),
        Text('\n'),
      ]),
    );
  });
}

void _checkEqual(AstNode a, AstNode b) {
  b.accept(_EqualityEnforcingVisitor(a), null);
}

class _EqualityEnforcingVisitor extends AstVisitor<void, void> {
  // The current ast node. Visitor methods will compare the node they receive to
  // this one.
  AstNode _current;

  _EqualityEnforcingVisitor(this._current);

  @override
  void visitAdjacentNodes(AdjacentNodes e, void a) {
    _currentAs(e);
    _checkChildren(e);
  }

  @override
  void visitAttribute(Attribute e, void a) {
    _assert(_currentAs(e).key == e.key, e);
    _checkChildren(e);
  }

  @override
  void visitAwaitBlock(AwaitBlock e, void a) {
    final current = _currentAs<AwaitBlock>(e);
    _assert(
      current.isStream == e.isStream && e.variableName == e.variableName,
      e,
    );
    _checkChildren(e);
  }

  @override
  void visitComment(Comment e, void a) {
    _currentAs<Comment>(e);
  }

  @override
  void visitDartExpression(DartExpression e, void a) {
    _currentAs(e);
    _checkChildren(e);
  }

  @override
  void visitElement(Element e, void a) {
    _assert(_currentAs(e).tagName == e.tagName, e);
    _checkChildren(e);
  }

  @override
  void visitForBlock(ForBlock e, void a) {
    final current = _currentAs(e);

    _assert(current.elementVariableName == e.elementVariableName, e);
    _assert(current.indexVariableName == e.indexVariableName, e);
    _checkChildren(e);
  }

  @override
  void visitHtmlTag(HtmlTag e, void a) {
    _currentAs(e);
    _checkChildren(e);
  }

  @override
  void visitIfBlock(IfBlock e, void a) {
    _currentAs(e);
    _checkChildren(e);
  }

  @override
  void visitIfCondition(IfCondition e, void a) {
    _currentAs(e);
    _checkChildren(e);
  }

  @override
  void visitKeyBlock(KeyBlock e, void a) {
    _currentAs(e);
    _checkChildren(e);
  }

  @override
  void visitRawDartExpression(RawDartExpression e, void a) {
    _assert(_currentAs<RawDartExpression>(e).code == e.code, e);
  }

  @override
  void visitStringLiteral(StringLiteral e, void a) {
    _currentAs(e);
    _checkChildren(e);
  }

  @override
  void visitText(Text e, void a) {
    _assert(_currentAs<Text>(e).content == e.content, e);
  }

  void _assert(bool contentEqual, AstNode context) {
    if (!contentEqual) _notEqual(context);
  }

  void _check(AstNode? childOfCurrent, AstNode? childOfOther) {
    if (identical(childOfCurrent, childOfOther)) return;

    if ((childOfCurrent == null) != (childOfOther == null)) {
      throw _NotEqualException('$childOfCurrent and $childOfOther');
    }

    // Both non nullable here
    final savedCurrent = _current;
    _current = childOfCurrent!;
    childOfOther!.accept(this, null);
    _current = savedCurrent;
  }

  void _checkChildren(AstNode other) {
    final currentChildren = _current.children.iterator;
    final otherChildren = other.children.iterator;

    while (currentChildren.moveNext()) {
      if (otherChildren.moveNext()) {
        _check(currentChildren.current, otherChildren.current);
      } else {
        // Current has more elements than other
        throw _NotEqualException(
          "$_current and $other don't have an equal amount of children",
        );
      }
    }

    if (otherChildren.moveNext()) {
      // Other has more elements than current
      throw _NotEqualException(
        "$_current and $other don't have an equal amount of children",
      );
    }
  }

  T _currentAs<T extends AstNode>(T context) {
    final current = _current;
    if (current is T) return current;

    _notEqual(context);
  }

  Never _notEqual(AstNode other) {
    throw _NotEqualException('$_current and $other');
  }
}

/// Thrown by the [_EqualityEnforcingVisitor] when two nodes were determined to
/// be non-equal.
class _NotEqualException implements Exception {
  final String message;

  _NotEqualException(this.message);

  @override
  String toString() {
    return 'Not equal: $message';
  }
}
