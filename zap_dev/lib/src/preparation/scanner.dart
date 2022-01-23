import 'dart:typed_data';

import 'package:source_span/source_span.dart';
import 'package:zap_dev/src/preparation/syntactic_entity.dart';

import '../errors.dart';
import 'charcodes.g.dart';
import 'constants.dart';
import 'token.dart';

class Scanner {
  final Uint16List codeUnits;
  final SourceFile file;
  final ErrorReporter errors;

  int startOfToken = 0;
  int position = 0;

  Scanner(String contents, Uri uri, this.errors)
      : codeUnits = Uint16List.fromList(contents.codeUnits),
        file = SourceFile.decoded(contents.codeUnits, url: uri);

  void _error(FileSpan span, String message) {
    errors.reportError(ZapError(message, span));
  }

  Never _failure(FileSpan span, String message) {
    _error(span, message);
    throw ParsingException();
  }

  FileSpan _span(int start, int end) {
    return file.span(start, end);
  }

  FileSpan _spanUntilHere(int start) {
    return _span(start, position);
  }

  FileSpan _tokenSpan() => _span(startOfToken, position);

  Token _simpleToken(TokenType type) => Token(_tokenSpan(), type);

  bool get isAtEnd => position == codeUnits.length;

  bool _check(int charCode) {
    return !isAtEnd && codeUnits[position] == charCode;
  }

  bool _checkAny(Iterable<int> codes) {
    return !isAtEnd && codes.contains(codeUnits[position]);
  }

  /// Whether the text from the current position starts with `<`, or `{`.
  bool _hasTextInterruptingChar() {
    return _check($lt) || _check($lbrace);
  }

  void skipWhitespaceInTag() {
    const chars = [$space, $tab, $cr, $lf];
    while (_checkAny(chars)) {
      position++;
    }
  }

  /// Matches either:
  ///
  /// - a [TextToken]
  /// - a left angle
  /// - `{`, `{:`, `{{`, `{/` or '{@`
  Token nextForDom() {
    startOfToken = position;

    if (isAtEnd) {
      _failure(_tokenSpan(), 'Unexpected end of file');
    }

    if (_hasTextInterruptingChar()) {
      if (_check($lt)) {
        position++;

        if (_check($slash)) {
          position++;
          return _simpleToken(TokenType.leftAngleSlash);
        } else {
          return _simpleToken(TokenType.leftAngle);
        }
      }

      assert(_check($lbrace));
      position++;

      switch (codeUnits[position]) {
        case $slash:
          position++;
          return _simpleToken(TokenType.lbraceSlash);
        case $colon:
          position++;
          return _simpleToken(TokenType.lbraceColon);
        case $hash:
          position++;
          return _simpleToken(TokenType.lbraceHash);
        case $at:
          position++;
          return _simpleToken(TokenType.lbraceAt);
        default:
          return _simpleToken(TokenType.lbrace);
      }
    } else {
      return _text(_hasTextInterruptingChar);
    }
  }

  /// Matches either:
  ///
  /// - a single or a double quote
  /// - a `{` token
  /// - an identifier
  Token nextForAttribute() {
    startOfToken = position;
    if (isAtEnd) {
      _failure(_tokenSpan(), 'Expected a value for the attribute');
    }

    final peek = codeUnits[position];
    switch (peek) {
      case $apos:
        position++;
        return _simpleToken(TokenType.singleQuote);
      case $quot:
        position++;
        return _simpleToken(TokenType.doubleQuote);
      case $lbrace:
        position++;
        return _simpleToken(TokenType.lbrace);
    }

    return tagName(); // identifier
  }

  /// Matches either:
  ///
  ///  - a single or a double quote
  ///  - a `{{` token
  ///  - text
  Token nextForStringLiteral(int quoteChar) {
    if (isAtEnd) {
      _failure(_tokenSpan(), 'Unexpected end in string literal');
    }

    startOfToken = position;
    final peek = codeUnits[position];
    switch (peek) {
      case $apos:
        position++;
        return _simpleToken(TokenType.singleQuote);
      case $quot:
        position++;
        return _simpleToken(TokenType.doubleQuote);
      case $lbrace:
        position++;
        return _simpleToken(TokenType.lbrace);
    }

    return _text(() {
      return isAtEnd ||
          codeUnits[position] == quoteChar ||
          codeUnits[position] == $lbrace;
    });
  }

  TextToken _text(bool Function() textEndsHere) {
    assert(!textEndsHere());

    final buffer = StringBuffer();

    StringBuffer? escapeEntity;
    int ampersandPosition = 0;

    void process(int char) {
      final escape = escapeEntity;
      if (escape != null) {
        if (char == $semicolon) {
          // End of escape
          final name = escapeEntity.toString();

          if (entities.containsKey(name)) {
            buffer.write(name);
          } else {
            _error(_spanUntilHere(ampersandPosition),
                'Unknown escape entity &$name;');
          }

          escapeEntity = null;
          ampersandPosition = 0;
        }
      } else if (char == $amp) {
        ampersandPosition = position;
        escapeEntity = StringBuffer();
      } else {
        buffer.writeCharCode(char);
      }
    }

    while (!isAtEnd && !textEndsHere()) {
      process(codeUnits[position++]);
    }

    if (escapeEntity != null) {
      // Unfinished escape entity, add to text
      buffer
        ..writeCharCode($amp)
        ..write(escapeEntity);
    }

    return TextToken(_tokenSpan(), buffer.toString());
  }

  Token _identifier({
    required bool Function(int) canStart,
    required bool Function(int) canContinue,
    String errorWhenInvalidStart = 'Unexpected character',
  }) {
    startOfToken = position;

    if (isAtEnd) {
      _failure(_tokenSpan(), 'Unexpected end of file');
    }

    final first = codeUnits[position++];
    if (!canStart(first)) {
      _error(_tokenSpan(), errorWhenInvalidStart);
      return _simpleToken(TokenType.identifier);
    }

    while (!isAtEnd && canContinue(codeUnits[position])) {
      position++;
    }

    return _simpleToken(TokenType.identifier);
  }

  Token tagName() {
    return _identifier(
      canStart: (char) => char.isInLatinAlphabet,
      canContinue: (char) =>
          char == $_ || char == $minus || char == $colon || char.isAlphaNumeric,
      errorWhenInvalidStart: 'Expected a letter to start the tag name',
    );
  }

  Token? optionalComma() {
    startOfToken = position;
    if (_check($comma)) {
      position++;
      return _simpleToken(TokenType.comma);
    }
  }

  void expectIdentifier(String identifier) {
    final id = tagName();
    if (id.lexeme != identifier) {
      _failure(id.span, 'Expected $identifier');
    }
  }

  bool checkIdentifier(String identifier) {
    final old = position;
    bool matches;

    try {
      matches = tagName().lexeme == identifier;
    } on ParsingException {
      matches = false;
    }

    if (!matches) {
      position = old;
    }
    return matches;
  }

  bool hasTagName() {
    return !isAtEnd && codeUnits[position].isInLatinAlphabet;
  }

  Token rightBrace() {
    startOfToken = position;
    if (_check($rbrace)) {
      position++;
      return _simpleToken(TokenType.rbrace);
    }

    _failure(_tokenSpan(), 'Expected a } here');
  }

  Token? optionalAttributeKey() {
    if (!isAtEnd && codeUnits[position].isInLatinAlphabet) {
      return _identifier(
        canStart: (char) => char.isInLatinAlphabet,
        canContinue: (char) =>
            char == $colon ||
            char == $bar ||
            char == $_ ||
            char == $minus ||
            char.isAlphaNumeric,
        errorWhenInvalidStart: 'Expected a letter to start an attribute',
      );
    }
  }

  Token? optionalEquals() {
    startOfToken = position;
    if (_check($equal)) {
      position++;
      return _simpleToken(TokenType.equals);
    }
  }

  Token rightAngle({bool acceptSelfClosing = false}) {
    startOfToken = position;

    if (acceptSelfClosing) {
      if (_check($slash)) {
        position++;
        if (_check($gt)) {
          position++;
          return _simpleToken(TokenType.slashRightAngle);
        }
      }
    }

    if (_check($gt)) {
      position++;
      return _simpleToken(TokenType.rightAngle);
    }

    _failure(_tokenSpan(), 'Expected the tag to close here');
  }

  Token _raw(bool Function(int) endsAt) {
    startOfToken = position;
    if (isAtEnd) {
      _failure(_tokenSpan(), 'Unexpected end of file');
    }

    while (!isAtEnd && !endsAt(position)) {
      position++;
    }

    return _simpleToken(TokenType.raw);
  }

  RawRange rawUntilRightBrace() {
    var openedLeftBraces = 1;

    final start = _raw((i) {
      if (codeUnits[i] == $lbrace) {
        openedLeftBraces++;
        return false;
      } else if (codeUnits[i] == $rbrace) {
        return --openedLeftBraces == 0;
      } else {
        return false;
      }
    });

    startOfToken = position;
    if (_check($rbrace)) {
      position++;
      return RawRange(start, _simpleToken(TokenType.rbrace));
    }

    _failure(_tokenSpan(), 'Expected a } here');
  }
}

extension on int {
  bool get isInLatinAlphabet {
    return ($a <= this && this <= $z) || ($A <= this && this <= $Z);
  }

  bool get isNumeric => $0 <= this && this <= $9;

  bool get isAlphaNumeric => isNumeric || isInLatinAlphabet;
}

class RawRange {
  final Token raw;
  final Token end;

  RawRange(this.raw, this.end);
}
