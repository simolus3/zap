import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart' as css;
import 'package:path/path.dart' show url;

String rewriteComponentCss(
    List<String> imports, String source, String className) {
  final result = css.CssPrinter();
  css.parse(
    source,
    options: css.PreprocessorOptions(lessSupport: false),
  )
    ..visit(_AddComponentClass(className))
    ..visit(result);

  final finalCss = StringBuffer();
  for (final import in imports) {
    if (url.extension(import) == '.zap') {
      final cssExtension = url.setExtension(import, '.tmp.zap.css');
      finalCss.writeln('@import "$cssExtension"');
    }
  }

  finalCss.write(result);

  return result.toString();
}

class _AddComponentClass extends css.Visitor {
  final String className;

  _AddComponentClass(this.className);

  @override
  void visitSelector(css.Selector node) {
    final baseSelector =
        css.ClassSelector(css.Identifier(className, null), null);
    final results = <css.SimpleSelectorSequence>[];

    for (final additional in node.simpleSelectorSequences) {
      final simple = additional.simpleSelector;

      if (simple.isWildcard) {
        // We just replace `*` with the class name and don't need to change
        // anything else.
        results.add(css.SimpleSelectorSequence(
            baseSelector, null, additional.combinator));
      } else {
        results.add(additional);
        results.add(css.SimpleSelectorSequence(baseSelector, null));
      }
    }

    node.simpleSelectorSequences
      ..clear()
      ..addAll(results);

    super.visitSelector(node);
  }
}
