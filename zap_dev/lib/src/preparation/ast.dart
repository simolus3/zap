import 'package:source_span/source_span.dart';

import '../utils/dart.dart';
import 'token.dart';
import 'syntactic_entity.dart';

abstract class AstNode extends SyntacticEntity {
  Token? first, last;
  AstNode? parent;

  @override
  FileSpan get span {
    final start = first;
    final end = last;

    if (start == null || end == null) {
      throw StateError('Node $this does not have a span');
    }

    return start.span.expand(end.span);
  }

  Iterable<AstNode> get children;
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg);
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg);
}

mixin _NoChildren on AstNode {
  @override
  Iterable<AstNode> get children => const [];

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {}
}

abstract class DomNode implements AstNode {}

class AdjacentNodes extends AstNode implements DomNode {
  @override
  List<DomNode> children;

  AdjacentNodes(this.children);

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitAdjacentNodes(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    children = transformer.transformChildren(children, this, arg);
  }
}

class Element extends AstNode implements DomNode {
  final String tagName;
  List<Attribute> attributes;
  DomNode? innerContent;

  Element(this.tagName, this.attributes, this.innerContent);

  @override
  Iterable<AstNode> get children =>
      [...attributes, if (innerContent != null) innerContent!];

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitElement(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    attributes = transformer.transformChildren(attributes, this, arg);
    innerContent = transformer.transformNullableChild(innerContent, this, arg);
  }
}

class Comment extends AstNode with _NoChildren implements DomNode {
  Token? comment;

  Comment(this.comment);

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitComment(this, arg);
  }
}

class Text extends AstNode
    with _NoChildren
    implements DomNode, AttributeValue, PartOfStringLiteral {
  /// The content of this text, after escape sequences and entites have been
  /// replaced.
  final String content;

  Token? token;

  Text(this.content);

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitText(this, arg);
  }

  @override
  String toString() {
    return 'Text: ${dartStringLiteral(content)}';
  }
}

class Attribute extends AstNode {
  final String key;
  AttributeValue? value;

  Token? keyToken;
  Token? equalsToken;

  Attribute(this.key, this.value);

  @override
  Iterable<AstNode> get children => [if (value != null) value!];

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitAttribute(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    value = transformer.transformNullableChild(value, this, arg);
  }
}

abstract class AttributeValue implements AstNode {}

/// `DartExpression: "{{" <RawDartExpression> "}}"`
class DartExpression extends AstNode
    implements AttributeValue, DomNode, PartOfStringLiteral {
  Token? leftBraces;
  Token? rightBraces;

  RawDartExpression code;

  DartExpression(this.code);

  @override
  Iterable<AstNode> get children => [code];

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitDartExpression(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    code = transformer.transformChild(code, this, arg);
  }
}

abstract class PartOfStringLiteral implements AstNode {}

class StringLiteral extends AstNode implements AttributeValue {
  Token? leftQuotes;
  Token? rightQuotes;

  @override
  List<PartOfStringLiteral> children;

  StringLiteral(this.children);

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitStringLiteral(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    children = transformer.transformChildren(children, this, arg);
  }
}

class RawDartExpression extends AstNode with _NoChildren {
  final String code;
  Token? content;

  RawDartExpression(this.code);

  factory RawDartExpression.fromToken(Token token) {
    return RawDartExpression(token.lexeme)
      ..content = token
      ..first = token
      ..last = token;
  }

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitRawDartExpression(this, arg);
  }
}

abstract class Block implements DomNode {}

class IfBlock extends AstNode implements Block {
  RawDartExpression condition;
  DomNode then;
  DomNode? otherwise;

  IfBlock(this.condition, this.then, this.otherwise);

  @override
  Iterable<AstNode> get children =>
      [condition, then, if (otherwise != null) otherwise!];

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitIfBlock(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    condition = transformer.transformChild(condition, this, arg);
    then = transformer.transformChild(then, this, arg);
    otherwise = transformer.transformNullableChild(otherwise, this, arg);
  }
}

class AwaitBlock extends AstNode implements Block {
  final bool isStream;
  final String variableName;
  RawDartExpression futureOrStream;
  DomNode innerNodes;

  AwaitBlock(
      this.isStream, this.variableName, this.futureOrStream, this.innerNodes);

  @override
  Iterable<AstNode> get children => [futureOrStream, innerNodes];

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitAwaitBlock(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    futureOrStream = transformer.transformChild(futureOrStream, this, arg);
    innerNodes = transformer.transformChild(innerNodes, this, arg);
  }
}

class ForBlock extends AstNode implements Block {
  final String elementVariableName;
  final String? indexVariableName;

  RawDartExpression iterable;
  DomNode body;

  ForBlock(this.elementVariableName, this.indexVariableName, this.iterable,
      this.body);

  @override
  Iterable<AstNode> get children => [iterable, body];

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitForBlock(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    iterable = transformer.transformChild(iterable, this, arg);
    body = transformer.transformChild(body, this, arg);
  }
}

class KeyBlock extends AstNode implements Block {
  RawDartExpression expression;
  DomNode content;

  KeyBlock(this.expression, this.content);

  @override
  Iterable<AstNode> get children => [expression, content];

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitKeyBlock(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    expression = transformer.transformChild(expression, this, arg);
    content = transformer.transformChild(content, this, arg);
  }
}

class HtmlTag extends AstNode implements DomNode {
  RawDartExpression expression;

  HtmlTag(this.expression);

  @override
  Iterable<AstNode> get children => [expression];

  @override
  Res accept<Arg, Res>(AstVisitor<Arg, Res> visitor, Arg arg) {
    return visitor.visitHtmlTag(this, arg);
  }

  @override
  void transformChildren<Arg>(AstTransformer<Arg> transformer, Arg arg) {
    expression = transformer.transformChild(expression, this, arg);
  }
}

abstract class AstVisitor<Arg, Res> {
  Res visitAttribute(Attribute e, Arg a);
  Res visitStringLiteral(StringLiteral e, Arg a);

  Res visitAdjacentNodes(AdjacentNodes e, Arg a);
  Res visitComment(Comment e, Arg a);
  Res visitText(Text e, Arg a);
  Res visitElement(Element e, Arg a);

  Res visitIfBlock(IfBlock e, Arg a);
  Res visitForBlock(ForBlock e, Arg a);
  Res visitAwaitBlock(AwaitBlock e, Arg a);
  Res visitKeyBlock(KeyBlock e, Arg a);

  Res visitHtmlTag(HtmlTag e, Arg a);

  Res visitRawDartExpression(RawDartExpression e, Arg a);
  Res visitDartExpression(DartExpression e, Arg a);
}

abstract class GeneralizingVisitor<Arg, Res> extends AstVisitor<Arg, Res> {
  Res defaultNode(AstNode node, Arg a);

  @override
  Res visitAdjacentNodes(AdjacentNodes e, Arg a) => defaultNode(e, a);

  @override
  Res visitAttribute(Attribute e, Arg a) => defaultNode(e, a);

  @override
  Res visitAwaitBlock(AwaitBlock e, Arg a) => defaultNode(e, a);

  @override
  Res visitComment(Comment e, Arg a) => defaultNode(e, a);

  @override
  Res visitDartExpression(DartExpression e, Arg a) => defaultNode(e, a);

  @override
  Res visitElement(Element e, Arg a) => defaultNode(e, a);

  @override
  Res visitForBlock(ForBlock e, Arg a) => defaultNode(e, a);

  @override
  Res visitHtmlTag(HtmlTag e, Arg a) => defaultNode(e, a);

  @override
  Res visitIfBlock(IfBlock e, Arg a) => defaultNode(e, a);

  @override
  Res visitKeyBlock(KeyBlock e, Arg a) => defaultNode(e, a);

  @override
  Res visitRawDartExpression(RawDartExpression e, Arg a) => defaultNode(e, a);

  @override
  Res visitStringLiteral(StringLiteral e, Arg a) => defaultNode(e, a);

  @override
  Res visitText(Text e, Arg a) => defaultNode(e, a);
}

abstract class RecursiveVisitor<Arg, Res>
    extends GeneralizingVisitor<Arg, Res?> {
  @override
  Res? defaultNode(AstNode node, Arg a) {
    for (final child in node.children) {
      child.accept(this, a);
    }
    return null;
  }
}

typedef AstTransformer<Arg> = AstVisitor<Arg, AstNode>;

class Transformer<Arg> extends GeneralizingVisitor<Arg, AstNode> {
  @override
  AstNode defaultNode(AstNode node, Arg a) {
    return node..transformChildren(this, a);
  }
}

extension<Arg> on AstTransformer<Arg> {
  Node transformChild<Node extends AstNode>(
      Node child, AstNode parent, Arg arg) {
    return child.accept<Arg, AstNode>(this, arg) as Node..parent = parent;
  }

  Node? transformNullableChild<Node extends AstNode>(
      Node? child, AstNode parent, Arg arg) {
    if (child != null) {
      return transformChild(child, parent, arg);
    }
  }

  List<Node> transformChildren<Node extends AstNode>(
      List<Node> children, AstNode parent, Arg arg) {
    return [for (final child in children) transformChild(child, parent, arg)];
  }
}
