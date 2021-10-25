import 'node.dart';
import 'html.dart';
import 'template.dart';

class DartExpression extends AstNode {
  final String dartExpression;

  DartExpression(this.dartExpression);

  @override
  Iterable<AstNode> get children => const Iterable.empty();

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitDartExpression(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {}
}

class WrappedDartExpression extends AstNode
    implements AttributeValue, TemplateComponent {
  DartExpression expression;

  WrappedDartExpression(this.expression);

  @override
  Iterable<AstNode> get children => [expression];

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitWrappedDartExpression(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {
    expression = expression.accept(transformer, arg) as DartExpression;
  }
}
