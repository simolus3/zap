import 'dart.dart';
import 'node.dart';

abstract class TemplateComponent extends AstNode {}

abstract class Macro extends AstNode implements TemplateComponent {}

class IfStatement extends Macro {
  DartExpression condition;
  TemplateComponent then;
  TemplateComponent? otherwise;

  IfStatement(this.condition, this.then, this.otherwise);

  @override
  Iterable<AstNode> get children =>
      [condition, then, if (otherwise != null) otherwise!];

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitIfStatement(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {
    condition = condition.accept(transformer, arg) as DartExpression;
    then = then.accept(transformer, arg) as TemplateComponent;
    otherwise = otherwise?.accept(transformer, arg) as TemplateComponent;
  }
}

class AsyncBlock extends Macro {
  bool isStream;
  String variableName;
  DartExpression futureOrStream;
  TemplateComponent body;

  AsyncBlock.future(this.variableName, this.futureOrStream, this.body)
      : isStream = false;

  AsyncBlock.stream(this.variableName, this.futureOrStream, this.body)
      : isStream = true;

  @override
  Iterable<AstNode> get children => [futureOrStream, body];

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitAsyncBlock(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {
    futureOrStream = futureOrStream.accept(transformer, arg) as DartExpression;
    body = body.accept(transformer, arg) as TemplateComponent;
  }
}

class Text extends TemplateComponent {
  String text;

  Text(this.text);

  @override
  Iterable<AstNode> get children => const Iterable.empty();

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitText(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {}
}

class AdjacentNodes extends TemplateComponent {
  List<TemplateComponent> nodes;

  @override
  Iterable<AstNode> get children => nodes;

  AdjacentNodes(this.nodes);

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitAdjacentNodes(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {
    nodes = [
      for (final oldNode in nodes)
        oldNode.accept(transformer, arg) as TemplateComponent
    ];
  }
}
