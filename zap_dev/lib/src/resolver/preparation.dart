import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../ast.dart';
import '../errors.dart';
import '../parser/parser.dart';
import '../utils/base32.dart';
import '../utils/dart.dart';
import 'style/add_class.dart';

const zapPrefix = '__zap__';
const componentFunctionWrapper = '${zapPrefix}_component';

Future<PrepareResult> prepare(
    String source, Uri sourceUri, ErrorReporter reporter) async {
  var component = Parser(source, sourceUri, reporter).parse();
  component = component.accept(_RewriteMixedDartExpressions(), null)
      as TemplateComponent;

  final checker = _ComponentSanityChecker(reporter);
  component.accept(checker, null);

  final fileBuilder = StringBuffer();
  final script = checker.script?.readInnerText(reporter);
  var imports = '';
  ScriptComponents? splitScript;

  if (script != null) {
    splitScript =
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
  _DartExpressionWriter(fileBuilder).start(checker._rootScope);

  if (script != null) {
    fileBuilder.writeln('}');
  }

  component = component.accept(_ExtractDom(), null) as TemplateComponent;

  final rawStyle = checker.style?.readInnerText(reporter);
  String? resolvedStyle;
  if (rawStyle != null) {
    final hash = utf8.encoder.fuse(sha1).convert(sourceUri.toString());
    final hashText =
        zbase32.convert(hash.bytes.sublist(0, min(hash.bytes.length, 16)));

    resolvedStyle = rewriteComponentCss(
        splitScript?.originalImports ?? [], rawStyle, hashText);
  }

  return PrepareResult._(
    imports,
    fileBuilder.toString(),
    resolvedStyle,
    checker._rootScope,
    component,
    checker.style,
    checker.script,
  );
}

class PrepareResult {
  final String imports;
  final String temporaryDartFile;
  final String? cssFile;
  final PreparedVariableScope rootScope;
  final TemplateComponent component;

  final Element? style;
  final Element? script;

  PrepareResult._(
    this.imports,
    this.temporaryDartFile,
    this.cssFile,
    this.rootScope,
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
  final PreparedVariableScope _rootScope = PreparedVariableScope();
  late PreparedVariableScope _scope = _rootScope;

  _ComponentSanityChecker(this.errors);

  @override
  void visitDartExpression(DartExpression e, void arg) {
    final expr = ScopedDartExpression(e, _scope);
    _scope.dartExpressions.add(expr);
  }

  @override
  void visitAsyncBlock(AsyncBlock e, void arg) {
    final previous = _scope;
    final child = AsyncBlockVariableScope(e)..parent = previous;

    // The target stream or future is evaluated in the parent scope
    e.futureOrStream.accept(this, arg);

    _scope = child;
    e.body.accept(this, arg);
    _scope = previous..children.add(child);
  }

  @override
  void visitIfStatement(IfStatement e, void arg) {
    final previous = _scope;
    final child = SubFragmentScope(e)..parent = previous;

    // The condition is still evaluated in the parent scope
    e.condition.accept(this, arg);

    _scope = child;
    e.then.accept(this, arg);
    e.otherwise?.accept(this, arg);
    _scope = previous..children.add(child);
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

class _DartExpressionWriter {
  final StringBuffer target;
  var _scopeCounter = 0;
  var _variableCounter = 0;

  _DartExpressionWriter(this.target);

  void writeVariable(ScopedDartExpression expr) {
    final variable = '$zapPrefix${_variableCounter++}';
    expr.localVariableName = variable;
    target.writeln('final $variable = ${expr.expression.dartExpression};');
  }

  void start(PreparedVariableScope root) {
    return _writeExpressionsAndChildren(root);
  }

  void _writeExpressionsAndChildren(PreparedVariableScope scope) {
    for (final expr in scope.dartExpressions) {
      writeVariable(expr);
    }

    for (final child in scope.children) {
      writeInnerScope(child);
    }
  }

  void writeInnerScope(PreparedVariableScope scope) {
    final name = '${zapPrefix}_scope_${_scopeCounter++}';
    scope.blockName = name;

    if (scope is AsyncBlockVariableScope) {
      target.writeln('$name<T>(ZapSnapshot<T> ${scope.block.variableName}) {');
    } else if (scope is SubFragmentScope) {
      // Just write a scope without parameters
      target.writeln('$name() {');
    }

    _writeExpressionsAndChildren(scope);
    target.writeln('}');
  }
}

class PreparedVariableScope {
  final Set<ScopedDartExpression> dartExpressions = {};
  final List<PreparedVariableScope> children = [];

  Macro? introducedFor;
  PreparedVariableScope? parent;

  /// The name of the function introduced in generated code to lookup this
  /// expression.
  String? blockName;
}

class AsyncBlockVariableScope extends PreparedVariableScope {
  final AsyncBlock block;

  AsyncBlockVariableScope(this.block) {
    introducedFor = block;
  }
}

class SubFragmentScope extends PreparedVariableScope {
  final Macro forNode;

  SubFragmentScope(this.forNode);
}

class ScopedDartExpression {
  final DartExpression expression;
  final PreparedVariableScope scope;

  /// The local variable introduced in generated code to hold this expression.
  late String localVariableName;

  ScopedDartExpression(this.expression, this.scope);
}

class _RewriteMixedDartExpressions extends Transformer<void> {
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
}

class _ExtractDom extends Transformer<void> {
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
