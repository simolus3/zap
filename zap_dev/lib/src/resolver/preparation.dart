import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../preparation/ast.dart';
import '../preparation/parser.dart';
import '../preparation/scanner.dart';
import '../errors.dart';
import '../utils/base32.dart';
import '../utils/dart.dart';
import 'style/scoped_css.dart';

const zapPrefix = '__zap__';
const componentFunctionWrapper = '${zapPrefix}_component';

Future<PrepareResult> prepare(
    String source, Uri sourceUri, ErrorReporter reporter) async {
  final scanner = Scanner(source, sourceUri, reporter);
  final parser = Parser(scanner);
  var component = parser.parse();

  final findSlots = _FindSlotTags();
  component.accept(findSlots, null);

  component.transformChildren(_RewriteMixedDartExpressions(), null);

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
  }

  // Analyze as script as if it were written in a function to allow
  // statements.
  fileBuilder
    ..writeln("import 'dart:html';")
    ..writeln("import 'package:zap/internal/dsl.dart';")
    ..writeln(imports)
    ..writeln('void $componentFunctionWrapper(ComponentOrPending self) {')
    ..writeln(splitScript?.body ?? '');

  // The analyzer does not provide an API to parse and resolve expressions, so
  // write them as variables which we can then take a look at.
  _DartExpressionWriter(fileBuilder).start(checker._rootScope);

  // Also, write and annotate slots so that other build steps can reason about
  // the slots defined by a component.
  if (findSlots.definedSlots.isNotEmpty) {
    for (final slot in findSlots.definedSlots) {
      fileBuilder
          .writeln('@Slot(${slot == null ? 'null' : dartStringLiteral(slot)})');
    }
    fileBuilder.writeln('dynamic ${zapPrefix}__slots;');
  }

  fileBuilder.writeln('}');
  component = component.accept(_ExtractDom(), null) as DomNode;

  String? className;

  final rawStyle = checker.style?.readInnerText(reporter);
  var resolvedStyle = '';
  if (rawStyle != null) {
    final hash = utf8.encoder.fuse(sha1).convert(sourceUri.toString());
    final hashText =
        zbase32.convert(hash.bytes.sublist(0, min(hash.bytes.length, 8)));
    className = 'zap-$hashText';

    resolvedStyle = componentScss(
        rawStyle, className, splitScript?.originalImports ?? const []);
  }

  return PrepareResult._(
    imports,
    fileBuilder.toString(),
    resolvedStyle,
    className,
    checker._rootScope,
    component,
    findSlots.definedSlots.toList(),
    checker.style,
    checker.script,
  );
}

class PrepareResult {
  final String imports;
  final String temporaryDartFile;
  final String temporaryScss;

  /// The class name for this component, used to implement scoped styles.
  ///
  /// This can be null if the component has no styles associated with it.
  final String? cssClassName;
  final PreparedVariableScope rootScope;
  final DomNode component;

  /// All slots defined by this component. The unnamed slot is represented by
  /// `null`.
  final List<String?> slots;

  final Element? style;
  final Element? script;

  PrepareResult._(
    this.imports,
    this.temporaryDartFile,
    this.temporaryScss,
    this.cssClassName,
    this.rootScope,
    this.component,
    this.slots,
    this.style,
    this.script,
  );
}

class _ComponentSanityChecker extends RecursiveVisitor<void, void> {
  final ErrorReporter errors;

  var _isInTag = false;
  Element? script;
  Element? style;
  final PreparedVariableScope _rootScope = PreparedVariableScope();
  late PreparedVariableScope _scope = _rootScope;

  _ComponentSanityChecker(this.errors);

  @override
  void visitRawDartExpression(RawDartExpression e, a) {
    final expr = ScopedDartExpression(e, _scope);
    _scope.dartExpressions.add(expr);
  }

  @override
  void visitAwaitBlock(AwaitBlock e, void arg) {
    final previous = _scope;
    final child = AsyncBlockVariableScope(e)..parent = previous;

    // The target stream or future is evaluated in the parent scope
    e.futureOrStream.accept(this, arg);

    _scope = child;
    e.innerNodes.accept(this, arg);
    _scope = previous..children.add(child);
  }

  @override
  void visitForBlock(ForBlock e, void arg) {
    final previous = _scope;
    final child = ForBlockVariableScope(e)..parent = previous;

    // The iterable is evaluated in the parent scope
    e.iterable.accept(this, arg);

    _scope = child;
    e.body.accept(this, arg);
    _scope = previous..children.add(child);
  }

  @override
  void visitIfBlock(IfBlock e, void arg) {
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
  void visitKeyBlock(KeyBlock e, void a) {
    final previous = _scope;
    final child = SubFragmentScope(e)..parent = previous;

    // The expression is evaluated in the parent scope
    e.expression.accept(this, a);

    _scope = child;
    e.content.accept(this, a);
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
    target.writeln('final $variable = ${expr.expression.code};');
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
    } else if (scope is ForBlockVariableScope) {
      final indexVar = scope.block.indexVariableName;
      final elementParam = 'T ${scope.block.elementVariableName}';
      final params =
          indexVar == null ? elementParam : '$elementParam, int $indexVar';

      target.writeln('$name<T>($params) {');
    } else if (scope is SubFragmentScope) {
      // Just write a scope without parameters
      target.writeln('$name() {');
    }

    _writeExpressionsAndChildren(scope);
    target.writeln('}');
  }
}

class _FindSlotTags extends RecursiveVisitor<void, void> {
  /// All slots defined by this component. Contains the name of the slot, or
  /// `null` if it's the default unnamed slot.
  final Set<String?> definedSlots = {};

  @override
  void visitElement(Element e, void a) {
    if (e.tagName == 'slot') {
      String? name;

      for (final attribute in e.attributes) {
        if (attribute.key == 'name') {
          name = ((attribute.value as StringLiteral).children.single as Text)
              .content;
        }
      }

      definedSlots.add(name);
    }

    super.visitElement(e, a);
  }
}

class PreparedVariableScope {
  final Set<ScopedDartExpression> dartExpressions = {};
  final List<PreparedVariableScope> children = [];

  Block? introducedFor;
  PreparedVariableScope? parent;

  /// The name of the function introduced in generated code to lookup this
  /// expression.
  String? blockName;
}

class AsyncBlockVariableScope extends PreparedVariableScope {
  final AwaitBlock block;

  AsyncBlockVariableScope(this.block) {
    introducedFor = block;
  }
}

class ForBlockVariableScope extends PreparedVariableScope {
  final ForBlock block;

  ForBlockVariableScope(this.block);
}

class SubFragmentScope extends PreparedVariableScope {
  final Block forNode;

  SubFragmentScope(this.forNode);
}

class ScopedDartExpression {
  final RawDartExpression expression;
  final PreparedVariableScope scope;

  /// The local variable introduced in generated code to hold this expression.
  late String localVariableName;

  ScopedDartExpression(this.expression, this.scope);
}

class _RewriteMixedDartExpressions extends Transformer<void> {
  String _dartStringLiteralFor(Text text) {
    return text.content.replaceAll(r'$', r'\$');
  }

  @override
  AstNode visitText(Text e, void a) {
    if (e.parent is Attribute) {
      return DartExpression(RawDartExpression("'${_dartStringLiteralFor(e)}'"));
    }

    return e;
  }

  @override
  AstNode visitStringLiteral(StringLiteral e, void a) {
    // Rewrite a mixed literal and Dart expression to a single Dart expression.
    final buffer = StringBuffer("'");

    for (final component in e.children) {
      if (component is DartExpression) {
        buffer.write('\${${component.code.code}}');
      } else if (component is Text) {
        buffer.write(_dartStringLiteralFor(component));
      }
    }

    buffer.write("'");

    return DartExpression(RawDartExpression(buffer.toString()));
  }
}

class _ExtractDom extends Transformer<void> {
  @override
  AstNode visitAdjacentNodes(AdjacentNodes e, void arg) {
    final newNodes = <DomNode>[];
    var didHaveContent = false;
    var lastNonTextIndex = -1;

    for (final node in e.children) {
      if (node is Text) {
        if (didHaveContent) {
          newNodes.add(Text(node.content));
        } else {
          // Remove whitespace on the left
          final trimmed = node.content.trimLeft();
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
        newNodes.add(node.accept(this, arg) as DomNode);
        didHaveContent = true;
      }
    }

    // Remove trailing whitespace
    for (var i = newNodes.length - 1; i > lastNonTextIndex; i--) {
      final text = newNodes[i] as Text;

      final newText = text.content.trimRight();
      if (newText.isEmpty) {
        newNodes.removeLast();
      } else {
        newNodes[i] = Text(newText);
        break;
      }
    }

    return e..children = newNodes;
  }
}

extension on Element {
  String? readInnerText(ErrorReporter reporter) {
    final child = innerContent;

    if (child is Text) {
      return child.content;
    } else {
      reporter.reportError(ZapError.onNode(child ?? this,
          'Expected a raw text string without Dart expressions or macros!'));
    }
  }
}
