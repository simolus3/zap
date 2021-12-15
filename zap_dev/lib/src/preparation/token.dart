import 'package:source_span/source_span.dart';

import 'syntactic_entity.dart';

enum TokenType {
  comment,
  whitespace,
  text,
  raw,
  identifier,
  equals,
  lbrace,
  lbraceColon,
  lbraceHash,
  lbraceSlash,
  lbraceAt,
  rbrace,
  leftAngle,
  leftAngleSlash,
  rightAngle,
  slashRightAngle,
  singleQuote,
  doubleQuote,
  comma,
}

class Token extends SyntacticEntity {
  @override
  final FileSpan span;

  final TokenType type;

  String get lexeme => span.text;

  Token(this.span, this.type);
}

class TextToken extends Token {
  final String value;

  TextToken(FileSpan span, this.value) : super(span, TokenType.text);
}
