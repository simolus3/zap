import 'package:source_span/source_span.dart';

import 'node.dart';
import 'template.dart';

class Element extends TemplateComponent {
  final String tagName;
  List<Attribute> attributes;
  TemplateComponent? child;

  Element(this.tagName, this.attributes, this.child);

  @override
  Iterable<AstNode> get children => [...attributes, if (child != null) child!];

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitElement(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {
    attributes = [
      for (final oldAttribute in attributes)
        oldAttribute.accept(transformer, arg) as Attribute,
    ];
    child = child?.accept(transformer, arg) as TemplateComponent?;
  }
}

class Attribute extends AstNode {
  final String key;
  AttributeValue? value;

  FileSpan? valueSpan;

  Attribute(this.key, this.value);

  @override
  Iterable<AstNode> get children => [if (value != null) value!];

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitAttribute(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {
    value = value?.accept(transformer, arg) as AttributeValue?;
  }
}

abstract class AttributeValue extends AstNode {}

class AdjacentAttributeStrings extends AttributeValue {
  List<AttributeValue> values;

  AdjacentAttributeStrings(this.values);

  @override
  Iterable<AstNode> get children => values;

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitAdjacentAttributeStrings(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {
    values = [
      for (final oldValue in values)
        oldValue.accept(transformer, arg) as AttributeValue
    ];
  }
}

class AttributeLiteral extends AttributeValue {
  final String value;

  AttributeLiteral(this.value);

  @override
  Iterable<AstNode> get children => const Iterable.empty();

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitAttributeLiteral(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {}
}
