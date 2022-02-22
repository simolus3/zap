import '../errors.dart';
import 'ast.dart';
import 'constants.dart';
import 'charcodes.g.dart';
import 'scanner.dart';
import 'token.dart';

class Parser {
  final Scanner scanner;
  final _NodeBuilder _builder = _NodeBuilder();

  final List<_PendingNode> _openedNodes = [];

  Parser(this.scanner);

  DomNode parse() {
    while (!scanner.isAtEnd) {
      _parseNode();
    }

    if (_openedNodes.isNotEmpty) {
      scanner.errors
          .reportError(ZapError('Some elements were not closed', null));
    }

    return _builder.build()..accept(_SetParentVisitor(), null);
  }

  void _errorOnToken(Token token, String message) {
    scanner.errors.reportError(ZapError(message, token.span));
  }

  void _parseNode() {
    final token = scanner.nextForDom();

    switch (token.type) {
      case TokenType.text:
        _finishNode(Text((token as TextToken).value)
          ..token = token
          ..first = token
          ..last = token);
        break;
      case TokenType.lbrace:
        _finishNode(_parseDartExpression(token));
        break;
      case TokenType.leftAngle:
        _parseElement(token);
        return;
      case TokenType.lbraceHash:
        _parseBlock(token);
        return;
      case TokenType.lbraceColon:
        final last = _openedNodes.last;
        if (last is _PendingBlock) {
          last.handlePart(this, token);
        } else {
          _errorOnToken(token, 'Not in a tag');
        }
        break;
      case TokenType.lbraceSlash:
        final last = _openedNodes.removeLast();
        if (last is _PendingBlock) {
          _finishNode(last.finish(this, token));
        } else {
          _errorOnToken(token, 'Not in a tag');
        }
        break;
      case TokenType.leftAngleSlash:
        _finishNode(_openedNodes.removeLast().finish(this, token));
        return;
      case TokenType.lbraceAt:
        _specialTag();
        return;
      default:
        throw StateError('Internal error: Unexpected token');
    }
  }

  void _finishNode(DomNode node) {
    if (_openedNodes.isNotEmpty) {
      _openedNodes.last.handleInnerNode(node);
    } else {
      _builder.add(node);
    }
  }

  /// Parses an [Element], assuming that the initial `<` has already been
  /// parsed.
  void _parseElement(Token langle) {
    scanner.skipWhitespaceInTag();
    final tagName = scanner.tagName();
    scanner.skipWhitespaceInTag();

    final attributes = <Attribute>[];
    Token? attributeKey;
    while ((attributeKey = scanner.optionalAttributeKey()) != null) {
      scanner.skipWhitespaceInTag();

      final key = attributeKey!.lexeme;
      final equalsSign = scanner.optionalEquals();
      AttributeValue? value;

      if (equalsSign != null) {
        scanner.skipWhitespaceInTag();
        value = _parseAttributeValue();
      }

      attributes.add(Attribute(key, value)
        ..keyToken = attributeKey
        ..equalsToken = equalsSign
        ..first = attributeKey
        ..last = value != null ? value.last : attributeKey);
      scanner.skipWhitespaceInTag();
    }

    final endOfFirstTag = scanner.rightAngle(acceptSelfClosing: true);
    final tagNameContents = tagName.lexeme.toLowerCase();

    if (endOfFirstTag.type == TokenType.slashRightAngle ||
        isVoidElement(tagNameContents)) {
      _finishNode(Element(tagName.lexeme, attributes, null)
        ..first = langle
        ..last = endOfFirstTag);
    } else if (tagNameContents == 'script' || tagNameContents == 'style') {
      // Fast-forward until we see this tag being closed
      final contents = StringBuffer();
      var next = scanner.nextForDom();

      while (true) {
        if (next.type == TokenType.leftAngleSlash) {
          scanner.skipWhitespaceInTag();
          final closingTagName = scanner.tagName();
          if (closingTagName.lexeme == tagName.lexeme) {
            break;
          }
        }

        contents.write(next.lexeme);
        next = scanner.nextForDom();
      }

      scanner
        ..skipWhitespaceInTag()
        ..rightAngle();
      _finishNode(
          Element(tagNameContents, attributes, Text(contents.toString())));
    } else {
      _openedNodes.add(_PendingElement(langle, tagName.lexeme, attributes));
    }
  }

  void _parseBlock(Token braceHash) {
    scanner.skipWhitespaceInTag();
    final first = scanner.tagName();

    _PendingBlock block;

    switch (first.lexeme) {
      case 'if':
        final remaining = scanner.rawUntilRightBrace();
        block = _PendingIfStatement(RawDartExpression.fromToken(remaining.raw));
        break;
      case 'await':
        scanner.skipWhitespaceInTag();
        final isStream = scanner.checkIdentifier('each');
        scanner.skipWhitespaceInTag();
        final name = scanner.tagName();
        scanner.skipWhitespaceInTag();
        scanner.expectIdentifier('from');
        scanner.skipWhitespaceInTag();

        final remaining = scanner.rawUntilRightBrace();
        block = _PendingAsyncBlock(
            isStream, RawDartExpression.fromToken(remaining.raw), name.lexeme);
        break;
      case 'for':
        scanner.skipWhitespaceInTag();
        final element = scanner.tagName();
        scanner.skipWhitespaceInTag();
        String? indexName;
        if (scanner.optionalComma() != null) {
          scanner.skipWhitespaceInTag();
          indexName = scanner.tagName().lexeme;
          scanner.skipWhitespaceInTag();
        }
        scanner.expectIdentifier('in');
        scanner.skipWhitespaceInTag();

        final remaining = scanner.rawUntilRightBrace();
        block = _PendingForBlock(element.lexeme, indexName,
            RawDartExpression.fromToken(remaining.raw));
        break;
      case 'key':
        scanner.skipWhitespaceInTag();
        final expression = scanner.rawUntilRightBrace();

        block = _PendingKeyBlock(RawDartExpression.fromToken(expression.raw));
        break;
      default:
        _errorOnToken(first, 'Expected if, async or for here');
        return;
    }

    _openedNodes.add(block);
  }

  AttributeValue _parseAttributeValue() {
    final token = scanner.nextForAttribute();

    switch (token.type) {
      case TokenType.lbrace:
        return _parseDartExpression(token);
      case TokenType.identifier:
        return Text(token.lexeme)
          ..token = token
          ..first = token
          ..last = token;
      case TokenType.doubleQuote:
      case TokenType.singleQuote:
        return _parseStringLiteral(token);
      default:
        throw StateError('Internal error: Unexpected token');
    }
  }

  DartExpression _parseDartExpression(Token leftBrace) {
    final range = scanner.rawUntilRightBrace();
    return DartExpression(
      RawDartExpression(range.raw.lexeme)
        ..content = range.raw
        ..first = range.raw
        ..last = range.raw,
    )
      ..first = leftBrace
      ..last = range.end;
  }

  StringLiteral _parseStringLiteral(Token start) {
    final end = start.type == TokenType.singleQuote ? $apos : $quot;
    final parts = <PartOfStringLiteral>[];

    while (true) {
      final next = scanner.nextForStringLiteral(end);
      if (next.type == start.type) {
        // Last quote
        break;
      } else if (next.type == TokenType.lbrace) {
        parts.add(_parseDartExpression(next));
      } else {
        parts.add(Text(next.lexeme)
          ..token = next
          ..first = next
          ..last = next);
      }
    }

    return StringLiteral(parts);
  }

  /// Parses an `{@html` or `{@debug` tag.
  void _specialTag() {
    scanner.skipWhitespaceInTag();
    final type = scanner.tagName();
    scanner.skipWhitespaceInTag();

    switch (type.lexeme) {
      case 'html':
        final expression = scanner.rawUntilRightBrace();
        _finishNode(HtmlTag(RawDartExpression.fromToken(expression.raw)));
        break;
      default:
        _errorOnToken(type, 'Expect @html or @debug here.');
    }
  }
}

abstract class _PendingNode {
  void handleInnerNode(DomNode node);

  DomNode finish(Parser parser, Token startOfClosing);
}

class _PendingElement extends _PendingNode {
  final Token first;
  final String tagName;
  final List<Attribute> attributes;
  final _NodeBuilder content = _NodeBuilder();

  _PendingElement(this.first, this.tagName, this.attributes);

  @override
  void handleInnerNode(DomNode node) {
    content.add(node);
  }

  @override
  DomNode finish(Parser parser, Token startOfClosing) {
    if (startOfClosing.type != TokenType.leftAngleSlash) {
      parser._errorOnToken(
          startOfClosing, 'Expected $tagName to close here instead');
    }

    final closingName = parser.scanner.tagName();
    if (closingName.lexeme != tagName) {
      parser._errorOnToken(
          closingName, 'Expected $tagName to close here instead');
    }

    final last = parser.scanner.rightAngle();

    return Element(tagName, attributes, content.build())
      ..first = first
      ..last = last;
  }
}

abstract class _PendingBlock extends _PendingNode {
  void handlePart(Parser parser, Token braceColon);
}

class _PendingIfStatement extends _PendingBlock {
  final RawDartExpression expression;

  final _NodeBuilder children = _NodeBuilder();
  final List<_PendingElse> pendingElse = [];

  _PendingIfStatement(this.expression);

  @override
  void handleInnerNode(DomNode node) {
    if (pendingElse.isNotEmpty) {
      pendingElse.last.nodes.add(node);
    } else {
      children.add(node);
    }
  }

  @override
  void handlePart(Parser parser, Token braceColon) {
    final scanner = parser.scanner;

    scanner.skipWhitespaceInTag();
    scanner.expectIdentifier('else');
    scanner.skipWhitespaceInTag();

    if (scanner.hasTagName()) {
      scanner.expectIdentifier('if');
      scanner.skipWhitespaceInTag();

      final rest = scanner.rawUntilRightBrace();
      pendingElse.add(_PendingElse(RawDartExpression(rest.raw.lexeme)
        ..content = rest.raw
        ..first = rest.raw
        ..last = rest.raw));
    } else {
      pendingElse.add(_PendingElse(null));
      scanner.rightBrace();
    }
  }

  @override
  DomNode finish(Parser parser, Token startOfClosing) {
    parser.scanner.skipWhitespaceInTag();
    parser.scanner.expectIdentifier('if');
    parser.scanner.skipWhitespaceInTag();
    parser.scanner.rightBrace();

    final conditions = <IfCondition>[IfCondition(expression, children.build())];
    DomNode? otherwise;

    for (final pending in pendingElse) {
      final body = pending.nodes.build();

      if (pending.condition != null) {
        conditions.add(IfCondition(pending.condition!, body));
      } else {
        otherwise = body;
      }
    }

    return IfBlock(conditions, otherwise);
  }
}

class _PendingElse {
  final RawDartExpression? condition;
  final _NodeBuilder nodes = _NodeBuilder();

  _PendingElse(this.condition);
}

abstract class _PendingBlockWithoutParts extends _PendingBlock {
  final _NodeBuilder nodes = _NodeBuilder();
  final String _endTag;

  _PendingBlockWithoutParts(this._endTag);

  DomNode create(DomNode children);

  @override
  void handleInnerNode(DomNode node) {
    nodes.add(node);
  }

  @override
  DomNode finish(Parser parser, Token startOfClosing) {
    parser.scanner
      ..skipWhitespaceInTag()
      ..expectIdentifier(_endTag)
      ..skipWhitespaceInTag()
      ..rightBrace();

    return create(nodes.build());
  }

  @override
  void handlePart(Parser parser, Token braceColon) {
    parser._errorOnToken(
        braceColon, 'Unexpected option for an $_endTag block.');
  }
}

class _PendingAsyncBlock extends _PendingBlockWithoutParts {
  final bool isStream;
  final RawDartExpression expression;
  final String snapshotName;

  _PendingAsyncBlock(this.isStream, this.expression, this.snapshotName)
      : super('await');

  @override
  DomNode create(DomNode children) {
    return AwaitBlock(isStream, snapshotName, expression, children);
  }
}

class _PendingForBlock extends _PendingBlockWithoutParts {
  final String elementName;
  final String? indexName;
  final RawDartExpression expression;

  _PendingForBlock(this.elementName, this.indexName, this.expression)
      : super('for');

  @override
  DomNode create(DomNode children) {
    return ForBlock(elementName, indexName, expression, children);
  }
}

class _PendingKeyBlock extends _PendingBlockWithoutParts {
  final RawDartExpression expression;

  _PendingKeyBlock(this.expression) : super('key');

  @override
  DomNode create(DomNode children) {
    return KeyBlock(expression, children);
  }
}

class _SetParentVisitor extends RecursiveVisitor<AstNode?, void> {
  @override
  void defaultNode(AstNode node, AstNode? a) {
    node.parent = a;
    super.defaultNode(node, node);
  }
}

class _NodeBuilder {
  final List<DomNode> nodes = [];

  void add(DomNode node) {
    nodes.add(node);
  }

  void addAll(Iterable<DomNode> newNodes) => nodes.addAll(newNodes);

  DomNode build() {
    if (nodes.length != 1) {
      return AdjacentNodes(nodes);
    } else {
      return nodes.single;
    }
  }
}
