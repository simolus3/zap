import 'dart:typed_data';

import 'package:charcode/charcode.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart';
import 'package:source_span/source_span.dart';

import '../ast.dart';
import '../errors.dart';
import 'html.dart';

class Parser {
  final Uint16List _codeUnits;
  final Uri sourceUri;
  final ErrorReporter errors;
  final SourceFile file;

  Parser(String text, this.sourceUri, this.errors)
      : _codeUnits = Uint16List.fromList(text.codeUnits),
        file = SourceFile.fromString(text, url: sourceUri);

  TemplateComponent parse() {
    final tags = _findMacros();
    var lastOffset = 0;

    final results = <TemplateComponent>[];
    final handlerStack = <TagHandler>[];

    for (final tag in tags) {
      // Parse text from the previous location to the beginning of this macro
      // tag.
      final endOfText = tag.offsetOfLeftBrace;
      if (lastOffset < endOfText) {
        final part =
            _parseWithoutMacros(lastOffset, tag.offsetOfLeftBrace).toList();

        if (handlerStack.isEmpty) {
          // No current handler, so just add it to the top-level results
          results
              .addAll(_parseWithoutMacros(lastOffset, tag.offsetOfLeftBrace));
        } else if (part.isNotEmpty) {
          handlerStack.last
              .text(part.length > 1 ? AdjacentNodes(part) : part.single);
        }
      }

      // Now, handle this tag
      final afterOpening = _codeUnits[tag.offsetOfLeftBrace + 1];
      final content = String.fromCharCodes(Uint16List.sublistView(
          _codeUnits, tag.offsetOfLeftBrace + 2, tag.offsetOfRightBrace));
      tag
        ..tagSpecificContent = content
        ..contentOffset = tag.offsetOfLeftBrace + 2;

      switch (afterOpening) {
        case $hash:
          // Opening a new tag, e.g. `{#if answer == 42}`
          if (content.startsWith('if')) {
            handlerStack.add(_IfTagHandler()..start(this, tag));
          } else {
            errors.reportError(ZapError('Unknown tag',
                file.span(tag.offsetOfLeftBrace, tag.offsetOfRightBrace)));
          }
          break;
        case $colon:
          // Subtree for an opened tag, e.g. `{:else}`
          handlerStack.last.inner(this, tag);
          break;
        case $slash:
          // Closing a tag, e.g. `{/if}`
          results.add(handlerStack.removeLast().end(this, tag));
          break;
      }

      // And continue parsing after the tag
      lastOffset = tag.offsetOfRightBrace + 1;
    }

    if (lastOffset < _codeUnits.length) {
      // Parse the reminder of the text
      results.addAll(_parseWithoutMacros(lastOffset, _codeUnits.length));
    }

    if (results.isEmpty) {
      return Text('');
    } else if (results.length == 1) {
      return results.single;
    } else {
      return AdjacentNodes(results);
    }
  }

  Iterable<TemplateComponent> _parseWithoutMacros(int start, int endExclusive) {
    final p = ZapHtmlParser(
      String.fromCharCodes(
          Uint16List.sublistView(_codeUnits, start, endExclusive)),
      sourceUri.toString(),
    );
    final fragment = p.parseFragment();

    for (final error in p.errors) {
      final span = error.span;
      errors.reportError(ZapError(error.message,
          span != null ? file.span(span.start.offset, span.end.offset) : null));
    }

    return _HtmlTransformer().mapChildren(fragment);
  }

  List<_FoundMacroTag> _findMacros() {
    var offset = 0;
    final result = <_FoundMacroTag>[];

    while (offset < _codeUnits.length) {
      final char = _codeUnits[offset];
      if (char == $openBrace) {
        offset++;

        if (offset < _codeUnits.length) {
          final nextChar = _codeUnits[offset];
          if (nextChar == $at ||
              nextChar == $hash ||
              nextChar == $slash ||
              nextChar == $colon) {
            final offsetOfLeft = offset - 1;
            var amountOfOpenBraces = 1;
            var didFindEnd = false;

            // Scan for the closing }
            offset++;
            while (offset < _codeUnits.length) {
              final charHere = _codeUnits[offset];
              if (charHere == $openBrace) {
                amountOfOpenBraces++;
              } else if (charHere == $closeBrace) {
                amountOfOpenBraces--;
                if (amountOfOpenBraces == 0) {
                  result.add(_FoundMacroTag(offsetOfLeft, offset));
                  didFindEnd = true;
                  break;
                }
              }

              offset++;
            }

            if (!didFindEnd) {
              // report unclosed tag
            }
          }
        }
      } else {
        offset++;
        continue;
      }
    }

    return result;
  }
}

class _FoundMacroTag {
  final int offsetOfLeftBrace;
  final int offsetOfRightBrace;

  late int contentOffset;
  late String tagSpecificContent;

  _FoundMacroTag(this.offsetOfLeftBrace, this.offsetOfRightBrace);
}

class _HtmlTransformer {
  Iterable<TemplateComponent> mapChildren(html.Node node,
      {bool rawText = false}) {
    return node.nodes.expand((node) {
      if (node is html.Element) {
        return [mapElement(node)];
      } else if (node is html.Text) {
        return rawText ? [Text(node.text)] : mapText(node);
      } else {
        return const Iterable.empty();
      }
    });
  }

  Element mapElement(html.Element element) {
    final attributes = <Attribute>[];

    for (final attribute in element.attributes.entries) {
      final key = attribute.key.toString();
      final value = attribute.value;

      AttributeValue? mapped;

      if (value.isEmpty) {
        mapped == null;
      } else {
        final components = _mapTextLiteral(value).map((e) {
          if (e is Text) return AttributeLiteral(e.text);

          return e;
        }).toList();

        if (components.length == 1) {
          mapped = components.single as AttributeValue;
        } else {
          mapped = AdjacentAttributeStrings(components.cast());
        }
      }

      attributes.add(Attribute(key, mapped)
        ..span = element.attributeSpans?[key]
        ..valueSpan = element.attributeValueSpans?[key]);
    }

    final name = element.localName!;
    final children =
        mapChildren(element, rawText: name == 'script' || name == 'style')
            .toList();

    TemplateComponent? child;
    if (children.isEmpty) {
      child = null;
    } else if (children.length == 1) {
      child = children.single;
    } else {
      child = AdjacentNodes(children);
    }

    return Element(name, attributes, child);
  }

  Iterable<TemplateComponent> _mapTextLiteral(String text) sync* {
    // Find inline Dart expressions in this text
    final codeUnits = text.codeUnits;

    final currentBlock = StringBuffer();

    var isEscaping = false;
    for (var i = 0; i < codeUnits.length; i++) {
      final char = codeUnits[i];

      if (isEscaping) {
        currentBlock.writeCharCode(char);
        isEscaping = false;
      } else if (char == $backslash) {
        isEscaping = true;
      } else if (char == $openBrace) {
        // This finishes a text block
        if (currentBlock.isNotEmpty) {
          yield Text(currentBlock.toString());
          currentBlock.clear();
        }

        final startOffset = i;
        var amountOfOpenBraces = 1;
        // Skip until the closing brace
        i++;
        while (i < codeUnits.length) {
          if (codeUnits[i] == $openBrace) {
            amountOfOpenBraces++;
          } else if (codeUnits[i] == $closeBrace) {
            amountOfOpenBraces--;

            if (amountOfOpenBraces == 0) {
              final endOffset = i;
              yield WrappedDartExpression(
                  DartExpression(text.substring(startOffset + 1, endOffset)));
              break;
            }
          }

          i++;
        }
      } else {
        currentBlock.writeCharCode(char);
      }
    }

    if (currentBlock.isNotEmpty) {
      // Report the rest
      yield Text(currentBlock.toString());
    }
  }

  Iterable<TemplateComponent> mapText(html.Text text) {
    return _mapTextLiteral(text.text);
  }
}

abstract class TagHandler {
  void start(Parser parser, _FoundMacroTag tag);
  void text(TemplateComponent inner);
  void inner(Parser parser, _FoundMacroTag tag);
  TemplateComponent end(Parser parser, _FoundMacroTag tag);
}

class _IfTagHandler extends TagHandler {
  static final _if = RegExp(r'^\s*if\s*(.+)');
  static final _elseIf = RegExp(r'^\s*else\s+if\s*(.+)');

  late DartExpression condition;
  TemplateComponent? then;
  final List<_PendingElse> _else = [];
  var didSeeElse = false;

  @override
  void start(Parser parser, _FoundMacroTag tag) {
    final match = _if.firstMatch(tag.tagSpecificContent)!;
    final dartSource = match.group(1)!;
    final end = match.end + tag.contentOffset;
    condition = DartExpression(dartSource)
      ..span = parser.file.span(end - dartSource.length, end);
  }

  @override
  void text(TemplateComponent inner) {
    if (_else.isEmpty) {
      then = inner;
    } else {
      _else.last.body = inner;
    }
  }

  @override
  void inner(Parser parser, _FoundMacroTag tag) {
    if (didSeeElse) {
      parser.errors.reportError(ZapError(
          'Else block already seen, expected {/if}.',
          parser.file.span(tag.offsetOfLeftBrace, tag.offsetOfRightBrace)));
      return;
    }

    final elseIfMatch = _elseIf.firstMatch(tag.tagSpecificContent);
    if (elseIfMatch != null) {
      final dartSource = elseIfMatch.group(1)!;
      final end = elseIfMatch.end + tag.contentOffset;
      final pending = _PendingElse(DartExpression(dartSource)
        ..span = parser.file.span(end - dartSource.length, end));
      _else.add(pending);
    } else if (tag.tagSpecificContent.contains('else')) {
      didSeeElse = true;
      _else.add(_PendingElse(null));
    } else {
      parser.errors.reportError(ZapError(
          'Expected an else or an else if block here.',
          parser.file.span(tag.offsetOfLeftBrace, tag.offsetOfRightBrace)));
    }
  }

  @override
  TemplateComponent end(Parser parser, _FoundMacroTag tag) {
    TemplateComponent? otherwise;

    while (_else.isNotEmpty) {
      final block = _else.removeLast();
      if (otherwise == null) {
        otherwise = block.condition != null
            ? IfStatement(block.condition!, block.body!, null)
            : block.body;
      } else {
        otherwise = IfStatement(block.condition!, block.body!, otherwise);
      }
    }

    return IfStatement(condition, then!, otherwise);
  }
}

class _PendingElse {
  final DartExpression? condition;
  TemplateComponent? body;

  _PendingElse(this.condition);
}
