// ignore_for_file: implementation_imports

import 'package:sass_api/sass_api.dart' as sass;
import 'package:sass/src/ast/selector.dart' as sass;
import 'package:sass/src/visitor/serialize.dart' as sass;
import 'package:path/path.dart' show url;

String componentScss(String original, String className, List<String> imports) {
  final stylesheet = sass.Stylesheet.parse(original, sass.Syntax.scss);
  final transformer = _AddExplicitClasses(original, className);
  stylesheet.accept(transformer);

  final result = StringBuffer();

  for (final import in imports) {
    final extension = url.extension(import);

    if (import.endsWith('.zap')) {
      final parent = url.dirname(import);
      final name = url.basenameWithoutExtension(import);
      final newImport = url.normalize('$parent/_$name.zap.scss');

      result.writeln("@use '$newImport';");
    } else if (extension == '.scss' || extension == '.sass') {
      result.writeln("@use '$import';");
    }
  }

  result.writeln(transformer.source);
  return result.toString();
}

class _AddExplicitClasses extends sass.RecursiveStatementVisitor {
  String source;
  final String classToAdd;

  int _skew = 0;

  _AddExplicitClasses(this.source, this.classToAdd);

  void _replace(sass.AstNode node, String contents) {
    final span = node.span;
    final start = span.start.offset + _skew;
    final end = start + span.length;

    source = source.replaceRange(start, end, contents);
    _skew += contents.length - span.length;
  }

  void _transformRules(sass.Interpolation selector) {
    final parsed = sass.SelectorList.parse(selector.span.text);
    final result = StringBuffer();

    var firstSequence = true;
    for (final sequence in parsed.components) {
      if (!firstSequence) {
        result.write(', ');
      }

      for (final component in sequence.components) {
        if (component is sass.CompoundSelector) {
          if (!component.isWildcard) {
            for (final simple in component.components) {
              result.write(sass.serializeSelector(simple));
            }
          }
          result.write('.$classToAdd');
        } else if (component is sass.Combinator) {
          // Nothing to transform, just write the combinator.
          result.write(component);
        }
      }

      firstSequence = false;
    }

    _replace(selector, result.toString());
  }

  @override
  void visitStyleRule(sass.StyleRule node) {
    _transformRules(node.selector);
    super.visitStyleRule(node);
  }
}

extension on sass.CompoundSelector {
  bool get isWildcard {
    return components.length == 1 &&
        components.single is sass.UniversalSelector;
  }
}
