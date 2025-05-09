import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';

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

  final fileBuilder = TemporaryDartFile();
  final script = checker.script?.readInnerText(reporter);

  List<String> importedZapFiles = const [];
  ScriptComponents? splitScript;

  if (script != null) {
    splitScript =
        ScriptComponents.of(script, rewriteImports: ImportRewriteMode.zapToApi);

    importedZapFiles = [
      for (final import in splitScript.originalImports)
        if (url.extension(import) == '.zap') import
    ];
  }

  // Analyze as script as if it were written in a function to allow
  // statements.
  fileBuilder
    ..writeln("import 'package:web/web.dart';")
    ..writeln("import 'package:zap/internal/dsl.dart';");

  if (splitScript != null) {
    fileBuilder
      ..startWritingNode(checker.script!.innerContent!)
      ..writeln(splitScript.directives)
      ..finishNode();
  }

  fileBuilder
      .writeln('void $componentFunctionWrapper(ComponentOrPending self) {');

  if (splitScript != null) {
    fileBuilder
      ..startWritingNode(checker.script!.innerContent!,
          offsetInNode: splitScript.offsetOfBody)
      ..writeln(splitScript.body)
      ..finishNode();
  }

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

  final moduleScript = checker.moduleScript;
  if (moduleScript != null) {
    final contents = moduleScript.readInnerText(reporter);

    if (contents != null) {
      fileBuilder
        ..startWritingNode(moduleScript)
        ..write(contents)
        ..finishNode();
    }
  }

  component = component.accept(_ExtractDom(), null) as DomNode;

  String? className;

  final hasStyle = checker.style != null;
  final rawStyle = checker.style?.readInnerText(reporter) ?? '';
  var resolvedStyle = '';

  final hash = utf8.encoder.fuse(sha1).convert(sourceUri.toString());
  final hashText =
      zbase32.convert(hash.bytes.sublist(0, min(hash.bytes.length, 8)));
  className = 'zap-$hashText';

  resolvedStyle = componentScss(
      rawStyle, className, splitScript?.originalImports ?? const []);

  return PrepareResult._(
    splitScript?.directives ?? '',
    importedZapFiles,
    fileBuilder,
    resolvedStyle,
    hasStyle ? className : null,
    checker._rootScope,
    component,
    findSlots.definedSlots.toList(),
    checker.style,
    checker.script,
  );
}

class PrepareResult {
  final String imports;
  final List<String> importedZapFiles;

  final TemporaryDartFile temporaryDartFile;
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
    this.importedZapFiles,
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

/// A temporary Dart file containing contents of `<script>` tags and expressions
/// stored as variables so that we can easily analyze them later.
class TemporaryDartFile {
  final StringBuffer _buffer = StringBuffer();
  final List<RegionInTemporaryDartFile> regions = [];

  int _startOffsetForPending = 0;
  RegionInTemporaryDartFile Function(int)? _finishNode;

  String get contents => _buffer.toString();

  void write(Object content) => _buffer.write(content);

  void writeln([Object? content = '']) => _buffer.writeln(content);

  void startWritingNode(AstNode node, {int offsetInNode = 0}) {
    _startOffsetForPending = _buffer.length;
    _finishNode = (endOffset) => RegionInTemporaryDartFile(
          _startOffsetForPending,
          endOffset,
          node,
          startOffsetInNode: offsetInNode,
        );
  }

  void finishNode() {
    regions.add(_finishNode!(_buffer.length));
    _finishNode = null;
  }

  RegionInTemporaryDartFile? regionAt(int offset) {
    var low = 0;
    var high = regions.length - 1;

    while (low <= high) {
      var middle = (high + low) ~/ 2;
      final regionHere = regions[middle];

      if (regionHere.startOffset <= offset) {
        if (regionHere.endOffsetExclusive > offset) {
          // offset is in region
          return regionHere;
        } else {
          // region at middle ends before the offset.
          low = middle + 1;
        }
      } else {
        assert(regionHere.startOffset > offset);
        // region starts after the offset
        high = middle - 1;
      }
    }
  }
}

class RegionInTemporaryDartFile {
  final int startOffset;
  final int endOffsetExclusive;

  final AstNode createdForNode;
  final int startOffsetInNode;

  RegionInTemporaryDartFile(
      this.startOffset, this.endOffsetExclusive, this.createdForNode,
      {this.startOffsetInNode = 0});
}

class _ComponentSanityChecker extends RecursiveVisitor<void, void> {
  final ErrorReporter errors;

  var _isInTag = false;
  Element? script;
  Element? moduleScript;
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

    for (final condition in e.conditions) {
      // The condition is still evaluated in the parent scope
      condition.condition.accept(this, arg);

      final child = _scope = SubFragmentScope(condition)..parent = previous;
      condition.body.accept(this, arg);
      _scope = previous..children.add(child);
    }

    final otherwise = e.otherwise;
    if (otherwise != null) {
      final child = _scope = SubFragmentScope(e)..parent = previous;
      otherwise.accept(this, arg);
      _scope = previous..children.add(child);
    }
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
      final isModule =
          e.attributes.firstWhereOrNull((attr) => attr.key == 'context') !=
              null;

      if (isModule) {
        handleSpecial(moduleScript);
        moduleScript = e;
      } else {
        handleSpecial(script);
        script = e;
      }
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
  final TemporaryDartFile target;
  var _scopeCounter = 0;
  var _variableCounter = 0;

  _DartExpressionWriter(this.target);

  void writeVariable(ScopedDartExpression expr) {
    final variable = '$zapPrefix${_variableCounter++}';
    expr.localVariableName = variable;

    target
      ..write('final $variable = ')
      ..startWritingNode(expr.expression)
      ..write(expr.expression.code)
      ..finishNode()
      ..writeln(';');
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
      final extractFunction =
          scope.block.isStream ? 'extractFromStream' : 'extractFromFuture';
      final stream = scope.parent!
          .findExpression(scope.block.futureOrStream)
          .localVariableName;

      target
        ..writeln('$name(ZapSnapshot<T> ${scope.block.variableName}) {')
        ..writeln(
            'final ${scope.block.variableName} = $extractFunction($stream);');

      _writeExpressionsAndChildren(scope);
      target.writeln('}');
    } else if (scope is ForBlockVariableScope) {
      final iterable =
          scope.parent!.findExpression(scope.block.iterable).localVariableName;
      final indexVar = scope.block.indexVariableName;

      target
        ..writeln('$name() {')
        ..writeln(
            'final ${scope.block.elementVariableName} = extractFromIterable($iterable);');

      if (indexVar != null) {
        target.writeln('final int $indexVar;');
      }

      _writeExpressionsAndChildren(scope);
      target.writeln('}');
    } else if (scope is SubFragmentScope) {
      // Just write a scope without parameters
      target.writeln('$name() {');
      _writeExpressionsAndChildren(scope);
      target.writeln('}');
    }
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

  ScopedDartExpression findExpression(RawDartExpression expr) {
    return dartExpressions.singleWhere((e) => e.expression == expr);
  }
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
  final AstNode forNode;

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

  DartExpression _textToExpression(Text e) {
    return DartExpression(
      RawDartExpression("'${_dartStringLiteralFor(e)}'")
        ..first = e.first
        ..last = e.last,
    )
      ..first = e.first
      ..last = e.last;
  }

  @override
  AstNode visitText(Text e, void a) {
    if (e.parent is Attribute) {
      return _textToExpression(e);
    }

    return e;
  }

  @override
  AstNode visitStringLiteral(StringLiteral e, void a) {
    // Rewrite a mixed literal and Dart expression to a single Dart expression.
    if (e.children.length == 1) {
      final child = e.children.single;

      if (child is Text) {
        return _textToExpression(child);
      } else {
        return child;
      }
    }

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
  Text visitText(Text e, void a) {
    return Text(e.content.withoutDuplicateWhitespace);
  }

  @override
  AstNode visitAdjacentNodes(AdjacentNodes e, void arg) {
    final newNodes = <DomNode>[];
    var didHaveContent = false;
    var lastNonTextIndex = -1;

    for (final node in e.children) {
      if (node is Text) {
        if (didHaveContent) {
          newNodes.add(visitText(node, arg));
        } else {
          // Remove whitespace on the left
          final trimmed = node.content.withoutDuplicateWhitespace.trimLeft();
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
      return null;
    }
  }
}

extension on String {
  // Replace consecutive whitespace, or all tabs/newline characters with a
  // single space.
  static final RegExp _ignoreWhitespace = RegExp('[ \\n\\t]{2,}|[\\n\\t]+');

  String get withoutDuplicateWhitespace {
    return replaceAll(_ignoreWhitespace, ' ');
  }
}
