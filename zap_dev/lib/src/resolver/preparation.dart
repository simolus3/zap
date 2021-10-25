import '../ast.dart';
import '../errors.dart';
import '../parser/parser.dart';
import '../utils/dart.dart';

const zapPrefix = '__zap__';
const componentFunctionWrapper = '${zapPrefix}_component';

Future<PrepareResult> prepare(
    String source, Uri sourceUri, ErrorReporter reporter) async {
  var component = Parser(source, sourceUri, reporter).parse();
  final checker = _ComponentSanityChecker(reporter);
  component.accept(checker, null);

  final fileBuilder = StringBuffer();
  final script = checker.script?.readInnerText(reporter);
  final introducedExpressionVariables = <String, String>{};
  var imports = '';

  if (script != null) {
    final splitScript =
        ScriptComponents.of(script, rewriteImports: ImportRewriteMode.zapToApi);
    imports = splitScript.directives;

    // Analyze as script as if it were written in a function to allow
    // statements.
    fileBuilder
      ..writeln("import 'dart:html';")
      ..writeln("import 'package:zap/internal/dsl.dart';")
      ..writeln(splitScript.directives)
      ..writeln('void $componentFunctionWrapper(ComponentOrPending self) {')
      ..writeln(splitScript.body);
  }

  // The analyzer does not provide an API to parse and resolve expressions, so
  // write them as top-level fields which we can then take a look at.
  var counter = 0;
  for (final expression in checker.dartExpressions) {
    if (!introducedExpressionVariables.containsKey(expression)) {
      final variable = '$zapPrefix${counter++}';
      introducedExpressionVariables[expression] = variable;

      fileBuilder.writeln('final $variable = $expression;');
    }
  }

  if (script != null) {
    fileBuilder.writeln('}');
  }

  component = component.accept(_ComponentRewriter(), null) as TemplateComponent;

  return PrepareResult._(
    imports,
    fileBuilder.toString(),
    introducedExpressionVariables,
    component,
    checker.style,
    checker.script,
  );
}

class PrepareResult {
  final String imports;
  final String temporaryDartFile;
  final Map<String, String> introducedDartExpressions;
  final TemplateComponent component;

  final Element? style;
  final Element? script;

  PrepareResult._(
    this.imports,
    this.temporaryDartFile,
    this.introducedDartExpressions,
    this.component,
    this.style,
    this.script,
  );
}

class _ComponentSanityChecker extends RecursiveVisitor<void> {
  final ErrorReporter errors;

  var _isInTag = false;
  Element? script;
  Element? style;
  Set<String> dartExpressions = {};

  _ComponentSanityChecker(this.errors);

  @override
  void visitDartExpression(DartExpression e, void arg) {
    dartExpressions.add(e.dartExpression);
  }

  @override
  void visitElement(Element e, void arg) {
    final tagName = e.tagName;

    void handleSpecial(Element? previous) {
      if (previous != null) {
        errors.reportError(ZapError.onNode(
            e, 'This component already declared a <$tagName> tag!'));
      } else if (_isInTag) {
        errors.reportError(ZapError.onNode(
            e, '<$tagName> tags must appear at the top of a Zap component!'));
      }
    }

    if (e.tagName == 'script') {
      handleSpecial(script);
      script = e;
    }
    if (e.tagName == 'style') {
      handleSpecial(style);
      style = e;
    }

    // Visit children
    final inTagBefore = _isInTag;
    _isInTag = true;
    super.visitElement(e, arg);
    _isInTag = inTagBefore;
  }
}

class _ComponentRewriter extends Transformer<void> {
  @override
  AstNode visitAdjacentAttributeStrings(AdjacentAttributeStrings e, void arg) {
    // Rewrite a mixed literal and Dart expression to a single Dart expression.
    final buffer = StringBuffer("'");

    for (final component in e.values) {
      if (component is WrappedDartExpression) {
        buffer.write('\${${component.expression.dartExpression}}');
      } else if (component is AttributeLiteral) {
        buffer.write(component.value.replaceAll(r'$', r'\$'));
      }
    }

    buffer.write("'");

    return WrappedDartExpression(DartExpression(buffer.toString()));
  }

  @override
  AstNode visitAttributeLiteral(AttributeLiteral e, void arg) {
    return WrappedDartExpression(DartExpression("'${e.value}'"));
  }

  @override
  AstNode visitAdjacentNodes(AdjacentNodes e, void arg) {
    final newNodes = <TemplateComponent>[];
    var didHaveContent = false;
    var lastNonTextIndex = -1;

    for (final node in e.nodes) {
      if (node is Text) {
        if (didHaveContent) {
          newNodes.add(Text(node.text));
        } else {
          // Remove whitespace on the left
          final trimmed = node.text.trimLeft();
          if (trimmed.isEmpty) continue;

          newNodes.add(Text(trimmed));
          didHaveContent = true;
        }
      } else {
        if (node is Element &&
            (node.tagName == 'script' || node.tagName == 'style')) {
          // These two nodes are handled in the compiler and should not show
          // up in the generated DOM.
          continue;
        }

        lastNonTextIndex = newNodes.length;
        newNodes.add(node.accept(this, arg) as TemplateComponent);
        didHaveContent = true;
      }
    }

    // Remove trailing whitespace
    for (var i = newNodes.length - 1; i > lastNonTextIndex; i--) {
      final text = newNodes[i] as Text;

      final newText = text.text.trimRight();
      if (newText.isEmpty) {
        newNodes.removeLast();
      } else {
        newNodes[i] = Text(newText);
        break;
      }
    }

    return e..nodes = newNodes;
  }
}

extension on Element {
  String? readInnerText(ErrorReporter reporter) {
    final child = this.child;

    if (child is Text) {
      return child.text;
    } else {
      reporter.reportError(ZapError.onNode(child ?? this,
          'Expected a raw text string without Dart expressions or macros!'));
    }
  }
}
