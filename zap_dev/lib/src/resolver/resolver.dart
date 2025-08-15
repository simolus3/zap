import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';

import '../preparation/ast.dart' as zap;
import '../errors.dart';
import '../utils/dart.dart';
import 'component.dart';
import 'dart.dart';
import 'dart_resolver.dart';
import 'external_component.dart';
import 'flow.dart';
import 'optimization/optimizer.dart';
import 'preparation.dart';
import 'reactive_dom.dart';
import 'types/binding.dart';
import 'types/checker.dart';
import 'types/dom_types.dart';

const _reactiveUpdatesLabel = r'$';

class Resolver {
  final PrepareResult prepare;
  final LibraryElement preparedLibrary;
  final CompilationUnit preparedUnit;
  final ErrorReporter errorReporter;
  final String componentName;

  final _ScopeInformation _scope;
  final List<ExternalComponent> components = [];
  late final TypeChecker checker;
  late final _AnalyzeVariablesAndScopes _dartAnalysis;

  TypeProvider get typeProvider => preparedLibrary.typeProvider;
  TypeSystem get typeSystem => preparedLibrary.typeSystem;

  Resolver(
    this.prepare,
    this.preparedLibrary,
    this.preparedUnit,
    this.errorReporter,
    this.componentName,
  ) : _scope = _ScopeInformation(prepare.rootScope);

  Future<ResolvedComponent> resolve(DartResolver resolver) async {
    checker = await TypeChecker.checkerFor(
      typeProvider,
      typeSystem,
      errorReporter,
      resolver,
    );
    await _findExternalComponents(resolver);
    _dartAnalysis = _AnalyzeVariablesAndScopes(this);

    // Create resolved scopes and variables
    preparedUnit.accept(_dartAnalysis);

    final translator = _DomTranslator(this);
    prepare.component.accept(translator, null);
    final rootFragment = DomFragment(
      translator._finishChildGroup().children,
      _scope.resolvedRootScope,
    );

    final component = _FindComponents(
      this,
      rootFragment,
      prepare.slots,
    ).inferComponent();

    // Mark all variables read in a flow
    for (final flow in component.flows) {
      for (final variable in flow.dependencies.whereType<BaseZapVariable>()) {
        variable.isInReactiveRead = true;
      }
    }

    // Also, all variables using `watch()` in their initializer are definitely
    // mutable
    for (final variable
        in component.scope.declaredVariables.whereType<DartCodeVariable>()) {
      if (variable.initializer?.watched.isNotEmpty == true) {
        variable.isMutable = true;
      }
    }

    _assignUpdateFlags(_scope.scopes[_scope.root]!);
    return ResolvedComponent(
      componentName,
      component,
      prepare.cssClassName,
      preparedLibrary,
      preparedUnit,
      _dartAnalysis.userDefinedFunctions,
      Optimizer(component).optimize(),
    );
  }

  Future<void> _findExternalComponents(DartResolver resolver) async {
    void scanNamespace(LibraryElement lib) {
      for (final element in lib.classes) {
        final tagName = componentTagName(element);

        if (tagName != null) {
          components.add(_readComponent(tagName, element));
        }
      }
    }

    for (final imported in preparedLibrary.firstFragment.importedLibraries) {
      scanNamespace(imported);

      // Also consider libraries added with the `zap:additional_export` pragma.
      // It exists so that zap components can be exported without breaking
      // the compilation flow because the component files don't exist during
      // all stages of the build.
      Uri uri;

      try {
        uri = await resolver.uriForElement(imported);
      } catch (e, s) {
        // It's expected that we can't recover the asset id of SDK libraries,
        // so don't log that.
        if (!imported.name!.startsWith('dart.')) {
          log.fine('Could not recover asset id of ${imported.uri}', e, s);
        }

        continue;
      }

      for (final additional in additionalZapExports(uri, imported)) {
        final import = Uri.parse(
          rewriteUri(additional.toString(), ImportRewriteMode.zapToApi),
        );
        LibraryElement included;
        try {
          included = await resolver.resolveUri(import);
        } catch (e, s) {
          log.fine(
            'Additional export $import of $uri does not appear to be a library',
            e,
            s,
          );
          continue;
        }

        scanNamespace(included);
      }
    }
  }

  ExternalComponent _readComponent(String tagName, ClassElement element) {
    final parameters = <MapEntry<String, DartType>>[];
    var slots = <String?>[];

    for (final accessor in element.fields) {
      final getter = accessor.getter;
      final annotations = getter == null
          ? null
          : readSlotAnnotations(getter).toList();

      if (annotations != null && annotations.isNotEmpty) {
        // This is the getter introduced to represent slots
        slots = annotations;
      } else {
        parameters.add(MapEntry(accessor.name!, accessor.type));
      }
    }

    return ExternalComponent(element, tagName, parameters, slots);
  }

  void _assignUpdateFlags(ZapVariableScope scope, [int start = 0]) {
    for (final variable in scope.declaredVariables) {
      if (variable.needsUpdateTracking) {
        variable.updateSlot = start++;
      }
    }

    for (final watched in scope.usedDartExpressions.expand((e) => e.watched)) {
      watched.updateSlot = start++;
    }

    // Child scopes can re-use higher update numbers since variables in
    // different child scopes aren't visible to each other.
    for (final scope in scope.childScopes) {
      _assignUpdateFlags(scope, start);
    }
  }
}

class _ScopeInformation {
  final PreparedVariableScope root;

  final Map<PreparedVariableScope, ZapVariableScope> scopes = {};
  final Map<VariableElement, BaseZapVariable> variables = {};

  final Map<zap.RawDartExpression, ScopedDartExpression> expressionToScope = {};
  final Map<zap.RawDartExpression, ResolvedDartExpression> resolvedExpressions =
      {};

  ZapVariableScope get resolvedRootScope => scopes[root]!;

  _ScopeInformation(this.root) {
    void addExpressionsFrom(PreparedVariableScope scope) {
      for (final expr in scope.dartExpressions) {
        expressionToScope[expr.expression] = expr;
      }

      scope.children.forEach(addExpressionsFrom);
    }

    addExpressionsFrom(root);
  }

  void addVariable(BaseZapVariable variable) {
    variable.scope.declaredVariables.add(variable);
    variables[variable.element] = variable;
  }
}

class _AnalyzeVariablesAndScopes extends RecursiveAstVisitor<void> {
  var _isInReactiveRead = false;
  var _isInRootZapFunction = false;
  var _isInUserDefinedFunction = false;

  PreparedVariableScope scope;

  final Resolver resolver;

  final _ScopeInformation scopes;
  final List<ExecutableElement> definedFunctions = [];
  final List<LocalFunctionElement> userDefinedFunctions = [];

  _AnalyzeVariablesAndScopes(this.resolver)
    : scopes = resolver._scope,
      scope = resolver._scope.root;

  ZapVariableScope get zapScope => scopes.scopes[scope]!;

  BaseZapVariable? _variableFor(Element element) {
    return scopes.variables[element];
  }

  void _markMutable(Element? target) {
    if (target != null) {
      _variableFor(target)?.isMutable = true;
    }
  }

  ResolvedDartExpression _resolveExpression(zap.RawDartExpression expr) {
    return scopes.resolvedExpressions.putIfAbsent(expr, () {
      final scoped = scopes.expressionToScope[expr]!;
      final scope = scopes.scopes[scoped.scope]!;

      ZapVariableScope scopeForFunction = scope;
      // Some scopes don't have a helper function in the intermediate Dart file,
      // just use the one from the parent then.
      while (scopeForFunction.function == null) {
        scopeForFunction = scope.parent!;
      }

      final body =
          scopeForFunction.function!.functionExpression.body
              as BlockFunctionBody;
      final name = scoped.localVariableName;

      final declaration = body.block.statements
          .whereType<VariableDeclarationStatement>()
          .firstWhere((element) {
            return element.variables.variables.any(
              (v) => v.name.lexeme == name,
            );
          });

      final initializer = declaration.variables.variables.single.initializer!;
      return _resolveAstExpression(initializer, scope);
    });
  }

  ResolvedDartExpression _resolveAstExpression(
    Expression expr,
    ZapVariableScope scope,
  ) {
    final resolved = ResolvedDartExpression(
      expr,
      scope,
      dynamic: resolver.typeProvider.dynamicType,
    );
    expr.accept(_FindWatchedExpressions(this, resolved));

    return resolved;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final parent = node.parent;

    if (parent is FunctionDeclaration) {
      final element = parent.declaredFragment?.element;

      if (parent.name.lexeme.startsWith(zapPrefix)) {
        if (!_isInRootZapFunction) {
          scopes.scopes[scope] = ZapVariableScope(parent);

          // We're analyzing the function for the root scope. Read the element for
          // the "ComponentOrPending" parameter added to the helper code.
          final selfDecl = node.parameters?.parameters.single;
          final selfElement =
              node.parameters?.parameterFragments.single?.element;

          scopes.addVariable(SelfReference(zapScope, selfDecl!, selfElement!));
          _isInRootZapFunction = true;

          super.visitFunctionExpression(node);
          _isInRootZapFunction = false;
        } else {
          final currentScope = scope;
          final currentResolvedScope = zapScope;

          // This function introduces a new scope for a nested block.
          final child = scope.children.singleWhere(
            (e) => e.blockName == parent.name.lexeme,
          );

          scope = child;

          final resolvedScope = scopes.scopes[scope] = ZapVariableScope(parent);
          resolvedScope.parent = currentResolvedScope;
          currentResolvedScope.childScopes.add(resolvedScope);

          super.visitFunctionExpression(node);
          scope = currentScope;
        }

        return;
      } else if (_isInRootZapFunction) {
        // Don't visit functions from library-level scripts, we only care about
        // what's in the function created for zap analysis.
        userDefinedFunctions.add(element as LocalFunctionElement);
      }
    }

    final inUserDefinedBefore = _isInUserDefinedFunction;
    _isInUserDefinedFunction = true;
    super.visitFunctionExpression(node);
    _isInUserDefinedFunction = inUserDefinedBefore;
  }

  @override
  void visitLabeledStatement(LabeledStatement node) {
    // If we encounter a `$:` label in the outermost function, that's a
    // reactive update statement.
    if (scope == scopes.root &&
        node.labels.any((l) => l.label.name == _reactiveUpdatesLabel)) {
      final old = _isInReactiveRead;
      _isInReactiveRead = true;
      super.visitLabeledStatement(node);
      _isInReactiveRead = old;
    } else {
      super.visitLabeledStatement(node);
    }
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_isInUserDefinedFunction) {
      // We don't track variables declared in inner functions.
      return super.visitVariableDeclaration(node);
    }

    if (node.name.lexeme.startsWith(zapPrefix)) {
      // Artificial variable inserted to analyze inline expression from the DOM
      // tree.
      final old = _isInReactiveRead;
      _isInReactiveRead = true;

      super.visitVariableDeclaration(node);

      _isInReactiveRead = old;
    } else {
      final resolved = node.declaredElement;

      if (resolved is LocalVariableElement) {
        final currentScope = scope;
        BaseZapVariable variable;

        if (currentScope is ForBlockVariableScope &&
            resolved.name == currentScope.block.elementVariableName) {
          variable = SubcomponentVariable(
            scope: zapScope,
            declaration: node,
            type: resolved.type,
            element: resolved,
            kind: SubcomponentVariableKind.forBlockElement,
          )..isMutable = true;
        } else if (currentScope is ForBlockVariableScope &&
            resolved.name == currentScope.block.indexVariableName) {
          variable = SubcomponentVariable(
            scope: zapScope,
            declaration: node,
            type: resolved.type,
            element: resolved,
            kind: SubcomponentVariableKind.forBlockIndex,
          )..isMutable = true;
        } else if (currentScope is AsyncBlockVariableScope &&
            resolved.name == currentScope.block.variableName) {
          variable = SubcomponentVariable(
            scope: zapScope,
            declaration: node,
            type: resolved.type,
            element: resolved,
            kind: SubcomponentVariableKind.asyncSnapshot,
          )..isMutable = true;
        } else {
          assert(scope == scopes.root);

          final initializer = node.initializer;

          variable = DartCodeVariable(
            scope: zapScope,
            declaration: node,
            element: resolved,
            isProperty: isProp(resolved),
            initializer: initializer != null
                ? _resolveAstExpression(initializer, zapScope)
                : null,
          );
        }

        scopes.addVariable(variable);
      }

      super.visitVariableDeclaration(node);
    }
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _markMutable(node.writeElement);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _markMutable(node.writeElement);
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    _markMutable(node.writeElement);
    super.visitPrefixExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final staticElement = node.element;
    if (_isInReactiveRead && staticElement != null) {
      _variableFor(staticElement)?.isInReactiveRead = true;
    }

    if (isWatchFunctionFromDslLibrary(node)) {
      // Usage of the `watch()` macro. It may only be used in a variable
      // declaration, in which case that variable will be updated to the value
      // watched.
      final parent = node.parent;
      if (parent is! InvocationExpression || node != parent.function) {
        // Not used as a call (potentially torn off or something). We implement
        // `watch` as a macro, so this is forbidden.
        resolver.errorReporter.reportError(
          ZapError('watch() must be called directly', null),
        );
        return;
      }
    }
  }
}

class _FindWatchedExpressions extends RecursiveAstVisitor<void> {
  final _AnalyzeVariablesAndScopes _dartAnalysis;

  ResolvedDartExpression expression;

  _FindWatchedExpressions(this._dartAnalysis, this.expression);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isWatchFunctionFromDslLibrary(node.methodName)) {
      // Ok, we have a call to `watch()`!
      final watchedExpression = node.argumentList.arguments.singleOrNull;
      if (watchedExpression != null) {
        final oldExpression = expression;

        expression = _dartAnalysis._resolveAstExpression(
          watchedExpression,
          expression.scope,
        );
        watchedExpression.accept(this);
        oldExpression.watched.add(WatchedExpression(expression));

        expression = oldExpression;
        return;
      }
    }

    super.visitMethodInvocation(node);
  }
}

class _DomTranslator extends zap.AstVisitor<void, void> {
  static final _eventRegex = RegExp(r'^on:(\w+)(?:\|((?:\w|\|)+))?$');

  final Resolver resolver;

  ZapVariableScope get scope => resolver._scope.scopes[preparedScope]!;

  final List<PreparedVariableScope> _variableScopes;
  final List<_PendingChildren> _childScopes = [_PendingChildren()];

  TypeSystem get typeSystem => resolver.typeSystem;
  TypeProvider get typeProvider => resolver.typeProvider;
  ErrorReporter get errors => resolver.errorReporter;

  PreparedVariableScope get preparedScope => _variableScopes.last;

  _DomTranslator(this.resolver) : _variableScopes = [resolver._scope.root];

  ResolvedDartExpression _resolveExpression(zap.RawDartExpression expr) {
    return resolver._dartAnalysis._resolveExpression(expr);
  }

  void _newChildGroup([_PendingChildren? children]) {
    _childScopes.add(children ?? _PendingChildren());
  }

  void _addChild(ReactiveNode child, [String? slot]) {
    final children = _childScopes.last;

    if (!children.assignableSlotNames.contains(slot)) {
      // todo: report error
    } else if (slot == null) {
      children.children.add(child);
    } else {
      children.slotChildren.putIfAbsent(slot, () => []).add(child);
    }
  }

  _PendingChildren _finishChildGroup() => _childScopes.removeLast();

  void _enterScope(PreparedVariableScope scope) => _variableScopes.add(scope);

  /// Some scopes are necessary when some DOM nodes are treated as a fragment
  /// and generated into a separate class. In particular, this is true for slots
  /// which don't have their own scope in the language but generate into a new
  /// fragment. Having a 1:1 mapping between scopes and fragments simplifies the
  /// generator, so we sometimes add "fake" scopes to generate fragments for
  /// these components.
  ZapVariableScope _virtualChildScope() {
    final fakeChildScope = ZapVariableScope(null)..parent = scope;
    scope.childScopes.add(fakeChildScope);
    return fakeChildScope;
  }

  void _leaveScope() => _variableScopes.removeLast();

  DomFragment _newFragment(
    List<ReactiveNode> children, [
    ZapVariableScope? scope,
  ]) {
    return DomFragment(children, scope ?? this.scope);
  }

  @override
  void visitStringLiteral(zap.StringLiteral e, void a) {
    throw ArgumentError('Should have been desugared in the preparation step!');
  }

  @override
  void visitAdjacentNodes(zap.AdjacentNodes e, void arg) {
    for (final child in e.children) {
      child.accept(this, arg);
    }
  }

  @override
  void visitAwaitBlock(zap.AwaitBlock e, void arg) {
    _enterScope(
      preparedScope.children.singleWhere(
        (s) => s is AsyncBlockVariableScope && s.block == e,
      ),
    );

    final expr = _resolveExpression(e.futureOrStream);
    DartType inner;
    if (e.isStream) {
      inner = resolver.checker.checkStream(
        expr.staticType,
        e.futureOrStream.span,
      );
    } else {
      inner = resolver.checker.checkFuture(
        expr.staticType,
        e.futureOrStream.span,
      );
    }

    _newChildGroup();
    e.innerNodes.accept(this, arg);

    final block = ReactiveAsyncBlock(
      isStream: e.isStream,
      type: inner,
      expression: expr,
      fragment: _newFragment(_finishChildGroup().children),
    );
    _addChild(block);
    _leaveScope();
  }

  @override
  void visitAttribute(zap.Attribute e, void arg) {
    throw ArgumentError('Should not be reached');
  }

  @override
  void visitComment(zap.Comment e, void a) {
    // ignore
  }

  @override
  void visitRawDartExpression(zap.RawDartExpression e, void arg) {
    throw ArgumentError('Should not be reached');
  }

  @override
  void visitElement(zap.Element e, void arg) {
    List<ReactiveNode> readChildren() {
      _newChildGroup();
      e.innerContent?.accept(this, arg);
      return _finishChildGroup().children;
    }

    final external = resolver.components.firstWhereOrNull(
      (component) => component.tagName == e.tagName,
    );

    final binders = <ElementBinder>[];
    final handlers = <EventHandler>[];
    final attributes = <String, ReactiveAttribute>{};
    String? slot;

    for (final attribute in e.attributes) {
      final key = attribute.key;
      // The pre-process step will replace all attributes with Dart expressions.
      final value = attribute.value != null
          ? _resolveExpression((attribute.value as zap.DartExpression).code)
          : null;
      final dartExpression = value?.expression;

      final eventMatch = _eventRegex.firstMatch(key);
      if (eventMatch != null) {
        // This attribute uses the `on:` syntax to listen for events.
        final name = eventMatch.group(1)!;
        final modifiers =
            eventMatch
                .group(2)
                ?.split('|')
                .map(parseEventModifier)
                .whereType<EventModifier>()
                .toSet() ??
            const {};

        final checkResult = resolver.checker.checkEvent(
          attribute,
          name,
          dartExpression,
          canBeCustom: external != null,
        );
        handlers.add(
          EventHandler(
            name,
            checkResult.known,
            checkResult.dartType,
            modifiers,
            value,
            checkResult.dropParameter,
          ),
        );
      } else if (key.startsWith('bind:')) {
        // Bind an attribute of this element to a variable.
        final attributeName = key.substring('bind:'.length);

        final target = dartExpression;
        if (target is! SimpleIdentifier || target.element == null) {
          resolver.errorReporter.reportError(
            ZapError(
              'Target for `b<ind:` must be a local variable',
              attribute.value?.span,
            ),
          );
          continue;
        }
        final zapTarget = resolver._scope.variables[target.element];
        if (zapTarget is! DartCodeVariable) continue;

        zapTarget.isMutable = true;
        binders.add(
          resolver.checker.checkBindProperty(
            bindName: attributeName,
            elementTagName: e.tagName,
            targetVariable: zapTarget,
            attribute: attribute,
          ),
        );
      } else if (key == 'slot') {
        slot = (value!.expression as SimpleStringLiteral).value;
      } else {
        // A regular attribute it is then.
        final type = value!.staticType;
        AttributeMode mode;
        if (typeSystem.isPotentiallyNullable(type)) {
          mode = AttributeMode.setIfNotNullClearOtherwise;
        } else if (typeSystem.isAssignableTo(type, typeProvider.boolType)) {
          mode = AttributeMode.addIfTrue;
        } else {
          mode = AttributeMode.setValue;
        }

        attributes[key] = ReactiveAttribute(value, mode);
      }
    }

    if (external != null) {
      // Tag references another zap component
      _newChildGroup(_PendingChildren(assignableSlotNames: external.slotNames));
      e.innerContent?.accept(this, arg);
      final result = _finishChildGroup();

      // We're using virtual child scopes here because slots are generated into
      // fragments, and each fragment needs to have a unique scope.
      _addChild(
        SubComponent(
          component: external,
          expressions: {
            for (final attribute in attributes.entries)
              attribute.key: attribute.value.backingExpression,
          },
          defaultSlot: result.children.isEmpty
              ? null
              : _newFragment(result.children, _virtualChildScope()),
          slots: {
            for (final entry in result.slotChildren.entries)
              entry.key: _newFragment(entry.value, _virtualChildScope()),
          },
          eventHandlers: handlers,
        ),
        slot,
      );
    } else if (e.tagName == 'slot') {
      // Declares a slot mounting a fragment passed through another component.
      String? slotName;
      if (attributes.containsKey('name')) {
        final name = attributes['name']!.backingExpression.expression;
        if (name is SimpleStringLiteral) {
          slotName = name.value;
        }
      }

      // Use a virtual child scope because the default slot contents are
      // generated as a new fragment class.
      _addChild(
        MountSlot(slotName, _newFragment(readChildren(), _virtualChildScope())),
        slot,
      );
    } else if (e.tagName == 'zap:component') {
      final expr = attributes['this'];
      if (expr == null) {
        resolver.errorReporter.reportError(
          ZapError.onNode(
            e,
            'Components need a `this` attribute evaluating to the component',
          ),
        );
      } else {
        _addChild(DynamicSubComponent(expr.backingExpression));
      }
    } else {
      // Regular HTML component then
      final known = knownTags[e.tagName.toLowerCase()];
      _addChild(
        ReactiveElement(
          e.tagName,
          known,
          attributes,
          handlers,
          readChildren(),
          binders,
        ),
        slot,
      );
    }
  }

  @override
  void visitForBlock(zap.ForBlock e, void arg) {
    _enterScope(
      preparedScope.children.whereType<ForBlockVariableScope>().singleWhere(
        (s) => s.block == e,
      ),
    );

    _newChildGroup();
    e.body.accept(this, arg);
    final children = _finishChildGroup().children;

    final expr = _resolveExpression(e.iterable);
    final innerType = resolver.checker.checkIterable(
      expr.staticType,
      e.iterable.span,
    );

    _addChild(ReactiveFor(expr, innerType, _newFragment(children)));
    _leaveScope();
  }

  @override
  void visitHtmlTag(zap.HtmlTag e, void a) {
    final expression = _resolveExpression(e.expression);

    _addChild(
      ReactiveRawHtml(
        expression: expression,
        needsToString: !resolver.checker.isString(expression.staticType),
      ),
    );
  }

  @override
  void visitIfBlock(zap.IfBlock e, void arg) {
    final conditions = <ResolvedDartExpression>[];
    final whens = <DomFragment>[];
    DomFragment? otherwise;

    ResolvedDartExpression checkBoolean(zap.RawDartExpression dart) {
      final condition = _resolveExpression(dart);
      final type = condition.staticType;
      if (!typeSystem.isSubtypeOf(type, typeProvider.boolType)) {
        errors.reportError(ZapError('Not a `bool` expression!', dart.span));
      }

      return condition;
    }

    for (final condition in e.conditions) {
      _enterScope(
        preparedScope.children.singleWhere(
          (s) => s is SubFragmentScope && s.forNode == condition,
        ),
      );

      conditions.add(checkBoolean(condition.condition));
      _newChildGroup();
      condition.body.accept(this, arg);
      whens.add(_newFragment(_finishChildGroup().children));

      _leaveScope();
    }

    final otherwiseNode = e.otherwise;
    if (otherwiseNode != null) {
      _enterScope(
        preparedScope.children.singleWhere(
          (s) => s is SubFragmentScope && s.forNode == e,
        ),
      );
      _newChildGroup();
      otherwiseNode.accept(this, arg);
      otherwise = _newFragment(_finishChildGroup().children);
      _leaveScope();
    }

    _addChild(ReactiveIf(conditions, whens, otherwise));
  }

  @override
  void visitIfCondition(zap.IfCondition e, void a) {
    throw UnsupportedError('unreachable, handled in visitIf');
  }

  @override
  void visitKeyBlock(zap.KeyBlock e, void a) {
    _enterScope(
      preparedScope.children.singleWhere(
        (s) => s is SubFragmentScope && s.introducedFor == e,
      ),
    );

    _newChildGroup();
    e.content.accept(this, a);
    final expr = _resolveExpression(e.expression);
    final fragment = _newFragment(_finishChildGroup().children);

    _addChild(ReactiveKeyBlock(expr, fragment));
    _leaveScope();
  }

  @override
  void visitText(zap.Text e, void arg) {
    _addChild(ConstantText(e.content));
  }

  @override
  void visitDartExpression(zap.DartExpression e, void arg) {
    final expr = resolver._dartAnalysis._resolveExpression(e.code);

    // Tell the generator to add a .toString() call if this expression isn't a
    // string already.
    final needsToString = !resolver.checker.isString(expr.staticType);

    _addChild(ReactiveText(expr, needsToString));
  }
}

class _PendingChildren {
  final List<ReactiveNode> children = [];

  /// All slots that can be assigned in the current context (with the unnamed
  /// slot being represented as null).
  ///
  /// This set will be empty when not immediately below a subcomponent.
  final List<String?> assignableSlotNames;
  final Map<String, List<ReactiveNode>> slotChildren = {};

  _PendingChildren({this.assignableSlotNames = const [null]});
}

class _FindComponents {
  final Resolver resolver;
  final DomFragment root;
  final List<String?> usedSlots;

  _FindComponents(this.resolver, this.root, this.usedSlots);

  Component inferComponent() {
    final rootScope = resolver._scope.scopes[resolver._scope.root]!;
    final variables = {
      for (final variable in rootScope.declaredVariables)
        variable.element: variable,
    };

    final body =
        rootScope.function?.functionExpression.body as BlockFunctionBody;

    final resolved = _findFlowUpdates(variables, root, body.block.statements);

    return Component(
      resolved.subComponents,
      rootScope,
      root,
      resolved.flow,
      resolved.initializers,
      resolved.instanceFunctions,
      usedSlots,
    );
  }

  _FlowAndCategorizedStatements _findFlowUpdates(
    Map<Element, BaseZapVariable> variables,
    DomFragment fragment,
    List<Statement> statements,
  ) {
    final flows = <Flow>[];
    final functions = <FunctionDeclarationStatement>[];
    final initializers = <ComponentInitializer>[];
    final subComponents = <ResolvedSubComponent>[];

    Set<HasUpdateMask> findDependencies(
      ResolvedDartExpression expression, [
      Map<Element, BaseZapVariable>? localVariables,
    ]) {
      final found = <HasUpdateMask>{};
      found.addAll(
        _FindReadVariables.find(
          expression.expression,
          localVariables ?? variables,
        ),
      );

      for (final watched in expression.watched) {
        found.add(watched);

        // Handle the inner part of `watch()` calls also being mutable / nested
        // `watch()` calls.
        final dependenciesOfWatch = findDependencies(watched.expression);
        if (dependenciesOfWatch.isNotEmpty) {
          flows.add(Flow(dependenciesOfWatch, UpdateWatchable(watched)));
        }
      }

      return found;
    }

    // Find flow instructions in the component's Dart code
    outer:
    for (final stmt in statements) {
      if (stmt is LabeledStatement) {
        final isReactiveLabel = stmt.labels.any(
          (l) => l.label.name == _reactiveUpdatesLabel,
        );

        if (isReactiveLabel) {
          final inner = stmt.statement;
          final sideEffect = SideEffect(inner);

          flows.add(
            Flow(_FindReadVariables.find(inner, variables), sideEffect),
          );
          initializers.add(InitialSideEffect(sideEffect));
        } else {
          initializers.add(InitializeStatement(stmt, null));
        }
      } else if (stmt is FunctionDeclarationStatement) {
        if (!stmt.functionDeclaration.name.lexeme.startsWith(zapPrefix)) {
          functions.add(stmt);
        }
      } else {
        DartCodeVariable? initialized;

        if (stmt is VariableDeclarationStatement) {
          // Filter out __zap__var_1 variables that have only been created to
          // analyze expressions used in the DOM.
          for (final variable in stmt.variables.variables) {
            if (variable.name.lexeme.startsWith(zapPrefix)) {
              continue outer;
            }
            final zapVariable = variables[variable.declaredElement];
            if (zapVariable is DartCodeVariable) {
              initialized = zapVariable;

              if (zapVariable.isProperty) {
                // We need to generate special code to initialize properties as
                // they can be set as constructor parameters too.
                initializers.add(InitializeProperty(zapVariable));
                continue outer;
              }
            }
          }
        }

        initializers.add(InitializeStatement(stmt, initialized));

        if (initialized != null) {
          final zapInitializer = initialized.initializer;
          if (zapInitializer != null) {
            final dependencies = findDependencies(
              zapInitializer,
            ).whereType<WatchedExpression>().toSet();

            // If a variable uses `watch()` in it's initializer, re-assign it
            // when a watched expression updates.
            if (dependencies.isNotEmpty) {
              flows.add(
                Flow(
                  dependencies,
                  ReEvaluateVariableWithWatchInitializer(initialized),
                ),
              );
            }
          }
        }
      }
    }

    void resolveWithoutOwnStatements(
      DomFragment fragment, [
      bool isForSlot = false,
    ]) {
      final flows = _findFlowUpdates(variables, fragment, []);
      subComponents.add(
        ResolvedSubComponent(
          flows.subComponents,
          fragment.resolvedScope,
          fragment,
          flows.flow,
          isMountedInSlot: isForSlot,
        ),
      );
    }

    void resolveEventHandlers(List<EventHandler> eventHandlers) {
      for (final handler in eventHandlers) {
        final listener = handler.listener;
        final listenerIsMutable =
            listener is! FunctionReference && listener is! FunctionExpression;

        final relevantVariables = listenerIsMutable && listener != null
            ? _FindReadVariables.find(listener.expression, variables)
            : <BaseZapVariable>{};
        flows.add(Flow(relevantVariables, RegisterEventHandler(handler)));
      }
    }

    // And also infer it from the DOM
    void processNode(ReactiveNode node) {
      if (node is ReactiveText) {
        final relevant = findDependencies(node.expression);
        flows.add(Flow(relevant, ChangeText(node)));
      } else if (node is ReactiveElement) {
        resolveEventHandlers(node.eventHandlers);
        node.attributes.forEach((key, value) {
          final dependsOn = findDependencies(value.backingExpression);
          flows.add(Flow(dependsOn, ApplyAttribute(node, key)));
        });

        for (final binder in node.binders) {
          if (binder is BindProperty) {
            flows.add(Flow({binder.target}, ApplyBinding(node, binder)));
          }
        }

        node.children.forEach(processNode);
      } else if (node is ReactiveIf) {
        // Blocks in the if statement will be compiled to lightweight components
        // written into separate classes.
        // However, they don't have any initializer statements and user code.
        node.whens.forEach(resolveWithoutOwnStatements);

        final otherwise = node.otherwise;
        if (otherwise != null) {
          resolveWithoutOwnStatements(otherwise);
        }

        // The if should be updated if any variable referenced in any condition
        // updates.
        final dependencies = node.conditions.expand(findDependencies).toSet();

        flows.add(Flow(dependencies, UpdateBlockExpression(node)));
      } else if (node is ReactiveAsyncBlock) {
        final scope = node.fragment.resolvedScope;
        final snapshotVariable = scope.findForSubcomponent(
          SubcomponentVariableKind.asyncSnapshot,
        )!;
        final localDeclarations = {snapshotVariable.element: snapshotVariable};
        final childVariables = {...variables, ...localDeclarations};

        final flow = _findFlowUpdates(childVariables, node.fragment, []);
        subComponents.add(
          ResolvedSubComponent(
            flow.subComponents,
            scope,
            node.fragment,
            flow.flow,
          ),
        );

        flows.add(
          Flow(
            findDependencies(node.expression, childVariables),
            UpdateBlockExpression(node),
          ),
        );
      } else if (node is ReactiveFor) {
        final scope = node.fragment.resolvedScope;
        final localDeclarations = {
          for (final variable in scope.declaredVariables)
            variable.element: variable,
        };
        final childVariables = {...variables, ...localDeclarations};

        final flow = _findFlowUpdates(childVariables, node.fragment, []);
        subComponents.add(
          ResolvedSubComponent(
            flow.subComponents,
            scope,
            node.fragment,
            flow.flow,
          ),
        );

        flows.add(
          Flow(
            findDependencies(node.expression, childVariables),
            UpdateBlockExpression(node),
          ),
        );
      } else if (node is ReactiveAsyncBlock) {
        final flow = _findFlowUpdates(variables, node.fragment, []);
        subComponents.add(
          ResolvedSubComponent(
            flow.subComponents,
            node.fragment.resolvedScope,
            node.fragment,
            flow.flow,
          ),
        );
        flows.add(
          Flow(findDependencies(node.expression), UpdateBlockExpression(node)),
        );
      } else if (node is ReactiveRawHtml) {
        flows.add(
          Flow(findDependencies(node.expression), UpdateBlockExpression(node)),
        );
      } else if (node is MountSlot) {
        resolveWithoutOwnStatements(node.defaultContent);
      } else if (node is SubComponent) {
        final defaultSlot = node.defaultSlot;
        if (defaultSlot != null) {
          resolveWithoutOwnStatements(defaultSlot, true);
        }
        for (final namedSlot in node.slots.values) {
          resolveWithoutOwnStatements(namedSlot, true);
        }

        for (final assignedProperty in node.expressions.entries) {
          final relevantVariables = findDependencies(assignedProperty.value);

          if (relevantVariables.isNotEmpty) {
            flows.add(
              Flow(
                relevantVariables,
                ChangePropertyOfSubcomponent(node, assignedProperty.key),
              ),
            );
          }
        }

        resolveEventHandlers(node.eventHandlers);
      } else if (node is DynamicSubComponent) {
        flows.add(
          Flow(findDependencies(node.expression), UpdateBlockExpression(node)),
        );
      } else {
        node.children.forEach(processNode);
      }
    }

    fragment.rootNodes.forEach(processNode);
    return _FlowAndCategorizedStatements(
      flows,
      functions,
      initializers,
      subComponents,
    );
  }
}

class _FindReadVariables extends GeneralizingAstVisitor<void> {
  final Map<Element, BaseZapVariable> variables;
  final Set<BaseZapVariable> found = {};

  _FindReadVariables(this.variables);

  static Set<BaseZapVariable> find(
    AstNode node,
    Map<Element, BaseZapVariable> variables,
  ) {
    final visitor = _FindReadVariables(variables);
    node.accept(visitor);

    return visitor.found;
  }

  @override
  void visitFunctionBody(FunctionBody node) {
    // Don't consider variables used in child functions.
    return;
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // Only check RHS of assignment because the LHS doesn't _read_ variables.
    // todo: How should things like `foo.bar = baz` behave - do we count that
    // as reading `foo`?
    node.rightHandSide.accept(this);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    visitIdentifier(node.prefix);
    visitIdentifier(node.identifier);
  }

  @override
  void visitIdentifier(Identifier node) {
    final element = node.element;
    final variable = variables[element];

    if (variable != null) {
      found.add(variable);
    }
  }
}

class _FlowAndCategorizedStatements {
  final List<Flow> flow;
  final List<FunctionDeclarationStatement> instanceFunctions;
  final List<ComponentInitializer> initializers;
  final List<ResolvedSubComponent> subComponents;

  _FlowAndCategorizedStatements(
    this.flow,
    this.instanceFunctions,
    this.initializers,
    this.subComponents,
  );
}

class ResolvedComponent {
  final String componentName;
  final String? cssClassName;
  final Component component;
  final List<LocalFunctionElement> userDefinedFunctions;

  final OptimizationResults optimization;

  final LibraryElement resolvedTmpLibrary;
  final CompilationUnit _resolvedTmpUnit;

  TypeSystem get typeSystem => resolvedTmpLibrary.typeSystem;

  ResolvedComponent(
    this.componentName,
    this.component,
    this.cssClassName,
    this.resolvedTmpLibrary,
    this._resolvedTmpUnit,
    this.userDefinedFunctions,
    this.optimization,
  );

  /// Returns all declared members that should be copied into the final output.
  ///
  /// This includes members declared in a `<script context="module">` script.
  /// We can't copy them verbatim because we need to add explicit prefixes for
  /// imports.
  Iterable<CompilationUnitMember> get declarationsFromModuleScope {
    return _resolvedTmpUnit.declarations.where((e) {
      // Exclude synthetic nodes we only use for static analysis.
      if (e is NamedCompilationUnitMember) {
        return !e.name.lexeme.startsWith(zapPrefix);
      }

      return true;
    });
  }
}
