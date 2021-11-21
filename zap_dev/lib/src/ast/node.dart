import 'package:source_span/source_span.dart';

import 'dart.dart';
import 'html.dart';
import 'template.dart';

abstract class AstNode {
  FileSpan? span;

  R accept<A, R>(AstVisitor<A, R> visitor, A arg);
  void transformChildren<A>(Transformer<A> transformer, A arg);

  Iterable<AstNode> get children;
}

abstract class AstVisitor<A, R> {
  R visitDartExpression(DartExpression e, A arg);
  R visitWrappedDartExpression(WrappedDartExpression e, A arg);

  R visitElement(Element e, A arg);
  R visitAttribute(Attribute e, A arg);
  R visitAdjacentAttributeStrings(AdjacentAttributeStrings e, A arg);
  R visitAttributeLiteral(AttributeLiteral e, A arg);

  R visitIfStatement(IfStatement e, A arg);
  R visitAsyncBlock(AsyncBlock e, A arg);
  R visitText(Text e, A arg);
  R visitAdjacentNodes(AdjacentNodes e, A arg);
}

abstract class GeneralizingVisitor<A, R> extends AstVisitor<A, R> {
  R defaultNode(AstNode node, A arg);

  @override
  R visitAdjacentAttributeStrings(AdjacentAttributeStrings e, A arg) {
    return defaultNode(e, arg);
  }

  @override
  R visitAdjacentNodes(AdjacentNodes e, A arg) {
    return defaultNode(e, arg);
  }

  @override
  R visitAttribute(Attribute e, A arg) {
    return defaultNode(e, arg);
  }

  @override
  R visitAttributeLiteral(AttributeLiteral e, A arg) {
    return defaultNode(e, arg);
  }

  @override
  R visitDartExpression(DartExpression e, A arg) {
    return defaultNode(e, arg);
  }

  @override
  R visitElement(Element e, A arg) {
    return defaultNode(e, arg);
  }

  @override
  R visitIfStatement(IfStatement e, A arg) {
    return defaultNode(e, arg);
  }

  @override
  R visitAsyncBlock(AsyncBlock e, A arg) {
    return defaultNode(e, arg);
  }

  @override
  R visitText(Text e, A arg) {
    return defaultNode(e, arg);
  }

  @override
  R visitWrappedDartExpression(WrappedDartExpression e, A arg) {
    return defaultNode(e, arg);
  }
}

class Transformer<A> extends GeneralizingVisitor<A, AstNode> {
  @override
  AstNode defaultNode(AstNode node, A arg) {
    return node..transformChildren(this, arg);
  }
}

class RecursiveVisitor<A> extends GeneralizingVisitor<A, void> {
  @override
  void defaultNode(AstNode node, A arg) {
    for (final child in node.children) {
      child.accept(this, arg);
    }
  }
}
