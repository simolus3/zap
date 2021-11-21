import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/dart/element/type_visitor.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';

import '../ast.dart' as zap;
import '../errors.dart';
import '../utils/dart.dart';
import 'component.dart';
import 'dart.dart';
import 'external_component.dart';
import 'flow.dart';
import 'preparation.dart';
import 'reactive_dom.dart';
import 'types/checker.dart';
import 'types/dom_types.dart';

const _reactiveUpdatesLabel = r'$';

class Resolver {
  final PrepareResult prepare;
  final LibraryElement preparedLibrary;
  final CompilationUnit preparedUnit;
  final ErrorReporter errorReporter;
  final String componentName;

  final _ScopeInformation scope;
  final List<ExternalComponent> components = [];
  late final TypeChecker checker;
  late final _AnalyzeVariablesAndScopes dartAnalysis;

  TypeProvider get typeProvider => preparedLibrary.typeProvider;
  TypeSystem get typeSystem => preparedLibrary.typeSystem;

  Resolver(
    this.prepare,
    this.preparedLibrary,
    this.preparedUnit,
    this.errorReporter,
    this.componentName,
  ) : scope = _ScopeInformation(prepare.rootScope);

  Future<ResolvedComponent> resolve(BuildStep buildStep) async {
    checker = await TypeChecker.checkerFor(
        typeProvider, typeSystem, errorReporter, buildStep);
    _findExternalComponents();
    dartAnalysis = _AnalyzeVariablesAndScopes(this);

    // Create resolved scopes and variables
    preparedUnit.accept(dartAnalysis);

    final translator = _DomTranslator(this);
    prepare.component.accept(translator, null);
    final rootFragment =
        DomFragment(translator._currentChildren, scope.resolvedRootScope);

    final component = _FindComponents(this, rootFragment).inferComponent();

    // Mark all variables read in a flow
    for (final flow in component.flows) {
      for (final variable in flow.dependencies) {
        variable.isInReactiveRead = true;
      }
    }

    _assignUpdateFlags(scope.scopes[scope.root]!);
    return ResolvedComponent(componentName, component);
  }

  void _findExternalComponents() {
    preparedLibrary.importedLibraries
        .map((l) => l.exportNamespace)
        .fold<Map<String, Element>>(
            <String, Element>{},
            (names, ns) =>
                names..addAll(ns.definedNames)).forEach((name, element) {
      if (element is ClassElement && isComponent(element)) {
        components.add(_readComponent(name, element));
      }
    });
  }

  ExternalComponent _readComponent(String name, ClassElement element) {
    final parameters = <MapEntry<String, DartType>>[];

    for (final accessor in element.fields) {
      parameters.add(MapEntry(accessor.name, accessor.type));
    }

    // Note: We're not using element.name since the name may be aliased.
    return ExternalComponent(name, parameters);
  }

  void _assignUpdateFlags(ZapVariableScope scope, [int start = 0]) {
    for (final variable in scope.declaredVariables) {
      if (variable.needsUpdateTracking) {
        variable.updateSlot = start++;
      }
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
  final Map<LocalElement, BaseZapVariable> variables = {};

  final Map<zap.DartExpression, ScopedDartExpression> expressionToScope = {};
  final Map<zap.DartExpression, ResolvedDartExpression> resolvedExpressions =
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

const _substitution = _TypeSubstitution();

class _AnalyzeVariablesAndScopes extends RecursiveAstVisitor<void> {
  var _isInReactiveRead = false;
  var _hasSeenRootFunction = false;

  PreparedVariableScope scope;

  final Resolver resolver;

  final _ScopeInformation scopes;
  final List<ExecutableElement> definedFunctions = [];

  _AnalyzeVariablesAndScopes(this.resolver)
      : scopes = resolver.scope,
        scope = resolver.scope.root;

  ZapVariableScope get zapScope => scopes.scopes[scope]!;

  BaseZapVariable? _variableFor(Element element) {
    return scopes.variables[element];
  }

  void _markMutable(Element? target) {
    if (target != null) {
      _variableFor(target)?.isMutable = true;
    }
  }

  ResolvedDartExpression _resolveExpression(zap.DartExpression expr) {
    return scopes.resolvedExpressions.putIfAbsent(expr, () {
      final scoped = scopes.expressionToScope[expr]!;
      final scope = scopes.scopes[scoped.scope]!;
      final body = scope.function.functionExpression.body as BlockFunctionBody;
      final name = scoped.localVariableName;

      final declaration = body.block.statements
          .whereType<VariableDeclarationStatement>()
          .firstWhere((element) {
        return element.variables.variables.any((v) => v.name.name == name);
      });

      final dartExpr = declaration.variables.variables.single.initializer!;
      final type = dartExpr.staticType ?? resolver.typeProvider.dynamicType;

      return ResolvedDartExpression(dartExpr,
          type.acceptWithArgument(_substitution, scope.instantiation));
    });
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final element = node.declaredElement;

    if (!_hasSeenRootFunction) {
      scopes.scopes[scope] = ZapVariableScope(node);

      // We're analyzing the function for the root scope. Read the element for
      // the "ComponentOrPending" parameter added to the helper code.
      final selfDecl = node.functionExpression.parameters?.parameters.single;
      final selfElement =
          node.functionExpression.parameters?.parameterElements.single;

      scopes.addVariable(SelfReference(zapScope, selfDecl!, selfElement!));
      _hasSeenRootFunction = true;

      super.visitFunctionDeclaration(node);
    } else if (element != null && element.name.startsWith(zapPrefix)) {
      final currentScope = scope;
      final currentResolvedScope = zapScope;

      // This function introduces a new scope for a nested block.
      final child =
          scope.children.singleWhere((e) => e.blockName == node.name.name);

      scope = child;
      final substitution = Map.of(currentResolvedScope.instantiation);
      final resolvedScope = scopes.scopes[scope] =
          ZapVariableScope(node, instantiation: substitution);
      resolvedScope.parent = currentResolvedScope;
      currentResolvedScope.childScopes.add(resolvedScope);

      if (child is AsyncBlockVariableScope) {
        // Extract the inner type from the stream/future expression so that
        // the snapshot can be typed correctly.
        final block = child.block;
        final expr = _resolveExpression(block.futureOrStream);
        DartType inner;

        if (block.isStream) {
          inner = resolver.checker
              .checkStream(expr.type, block.futureOrStream.span);
        } else {
          inner = resolver.checker
              .checkFuture(expr.type, block.futureOrStream.span);
        }

        final function = node.functionExpression;
        final parameters = function.parameters!;

        final typeParam = function.typeParameters!.typeParameters.single;
        substitution[typeParam.declaredElement!] = inner;

        final snapshotDecl = parameters.parameters.single;
        final snapshotElem = parameters.parameterElements.single!;

        final snapshot = SubcomponentVariable(
          scope: resolvedScope,
          declaration: snapshotDecl,
          type:
              snapshotElem.type.acceptWithArgument(_substitution, substitution),
          element: snapshotElem,
          kind: SubcomponentVariableKind.asyncSnapshot,
        )..isMutable = true;
        scopes.addVariable(snapshot);
      }

      super.visitFunctionDeclaration(node);
      scope = currentScope;
    } else {
      return super.visitFunctionDeclaration(node);
    }
  }

  @override
  void visitLabeledStatement(LabeledStatement node) {
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
    if (node.name.name.startsWith(zapPrefix)) {
      // Artificial variable inserted to analyze inline expression from the DOM
      // tree.
      final old = _isInReactiveRead;
      _isInReactiveRead = true;

      super.visitVariableDeclaration(node);

      _isInReactiveRead = old;
    } else if (scope == scopes.root) {
      final resolved = node.declaredElement;

      if (resolved != null) {
        final variable = DartCodeVariable(
          scope: zapScope,
          declaration: node,
          element: resolved as LocalVariableElement,
          isProperty: isProp(resolved),
        );
        scopes.addVariable(variable);
      }
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
    final staticElement = node.staticElement;
    if (_isInReactiveRead && staticElement != null) {
      _variableFor(staticElement)?.isInReactiveRead = true;
    }
  }
}

class _DomTranslator extends zap.AstVisitor<void, void> {
  static final _eventRegex = RegExp(r'^on:(\w+)(?:\|(\w+))*$');

  final Resolver resolver;

  PreparedVariableScope preparedScope;

  ZapVariableScope get scope => resolver.scope.scopes[preparedScope]!;

  List<ReactiveNode> _currentChildren = [];

  TypeSystem get typeSystem => resolver.typeSystem;
  TypeProvider get typeProvider => resolver.typeProvider;
  ErrorReporter get errors => resolver.errorReporter;

  _DomTranslator(this.resolver) : preparedScope = resolver.scope.root;

  ResolvedDartExpression _resolveExpression(zap.DartExpression expr) {
    return resolver.dartAnalysis._resolveExpression(expr);
  }

  @override
  void visitAdjacentAttributeStrings(zap.AdjacentAttributeStrings e, void arg) {
    throw ArgumentError('Should have been desugared in the preparation step!');
  }

  @override
  void visitAdjacentNodes(zap.AdjacentNodes e, void arg) {
    for (final child in e.nodes) {
      child.accept(this, arg);
    }
  }

  DomFragment _newFragment(List<ReactiveNode> children) {
    return DomFragment(children, scope);
  }

  @override
  void visitAsyncBlock(zap.AsyncBlock e, void arg) {
    final oldScope = preparedScope;
    preparedScope = preparedScope.children
        .singleWhere((s) => s is AsyncBlockVariableScope && s.block == e);

    final expr = _resolveExpression(e.futureOrStream);
    DartType inner;
    if (e.isStream) {
      inner = resolver.checker.checkStream(expr.type, e.futureOrStream.span);
    } else {
      inner = resolver.checker.checkFuture(expr.type, e.futureOrStream.span);
    }

    final oldChildren = _currentChildren;
    _currentChildren = [];

    e.body.accept(this, arg);

    _currentChildren = oldChildren
      ..add(ReactiveAsyncBlock(
        isStream: e.isStream,
        type: inner,
        expression: expr,
        fragment: _newFragment(_currentChildren),
      ));

    preparedScope = oldScope;
  }

  @override
  void visitAttribute(zap.Attribute e, void arg) {
    throw ArgumentError('Should not be reached');
  }

  @override
  void visitAttributeLiteral(zap.AttributeLiteral e, void arg) {
    throw ArgumentError('Should not be reached');
  }

  @override
  void visitDartExpression(zap.DartExpression e, void arg) {
    throw ArgumentError('Should not be reached');
  }

  @override
  void visitElement(zap.Element e, void arg) {
    final old = _currentChildren;

    _currentChildren = [];
    e.child?.accept(this, arg);
    final childrenOfelement = _currentChildren;

    _currentChildren = old;

    final handlers = <EventHandler>[];
    final attributes = <String, ReactiveAttribute>{};

    for (final attribute in e.attributes) {
      final key = attribute.key;
      // The pre-process step will replace all attributes with Dart expressions.
      final value = _resolveExpression(
          (attribute.value as zap.WrappedDartExpression).expression);

      final eventMatch = _eventRegex.firstMatch(key);
      if (eventMatch != null) {
        // This attribute uses the `on:` syntax to listen for events.
        final name = eventMatch.group(1)!;
        final modifiers = List.generate(eventMatch.groupCount - 1,
                (index) => eventMatch.group(index + 1)!)
            .map(parseEventModifier)
            .whereType<EventModifier>()
            .toSet();

        final checkResult =
            resolver.checker.checkEvent(attribute, name, value.expression);
        handlers.add(EventHandler(name, checkResult.known, modifiers, value,
            checkResult.dropParameter));
      } else {
        // A regular attribute it is then.
        final type = value.type;
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

    final external = resolver.components
        .firstWhereOrNull((component) => component.className == e.tagName);

    if (external != null) {
      // Tag references another zap component
      _currentChildren.add(SubComponent(external, {}));
    } else {
      // Regular HTML component then
      final known = knownTags[e.tagName.toLowerCase()];
      _currentChildren.add(ReactiveElement(
          e.tagName, known, attributes, handlers, childrenOfelement));
    }
  }

  @override
  void visitIfStatement(zap.IfStatement e, void arg) {
    final oldScope = preparedScope;
    preparedScope = preparedScope.children
        .singleWhere((s) => s is SubFragmentScope && s.forNode == e);

    final conditions = <ResolvedDartExpression>[];
    final whens = <List<ReactiveNode>>[];
    List<ReactiveNode>? otherwise;

    ResolvedDartExpression checkBoolean(zap.DartExpression dart) {
      final condition = _resolveExpression(dart);
      final type = condition.type;
      if (!typeSystem.isSubtypeOf(type, typeProvider.boolType)) {
        errors.reportError(ZapError('Not a `bool` expression!', dart.span));
      }

      return condition;
    }

    zap.IfStatement? currentIf = e;
    while (currentIf != null) {
      conditions.add(checkBoolean(currentIf.condition));

      final oldChildren = _currentChildren;
      _currentChildren = [];

      e.then.accept(this, arg);
      whens.add(_currentChildren);

      _currentChildren = oldChildren;

      final orElse = e.otherwise;
      if (orElse is zap.IfStatement) {
        currentIf = orElse;
      } else if (orElse != null) {
        final oldChildren = _currentChildren;
        _currentChildren = [];

        orElse.accept(this, arg);
        otherwise = _currentChildren;

        _currentChildren = oldChildren;
        currentIf = null;
      }
    }

    final whenFragments = [for (final when in whens) _newFragment(when)];
    final otherwiseFragment =
        otherwise == null ? null : _newFragment(otherwise);

    _currentChildren
        .add(ReactiveIf(conditions, whenFragments, otherwiseFragment));
    preparedScope = oldScope;
  }

  @override
  void visitText(zap.Text e, void arg) {
    _currentChildren.add(ConstantText(e.text));
  }

  @override
  void visitWrappedDartExpression(zap.WrappedDartExpression e, void arg) {
    final expr = resolver.dartAnalysis._resolveExpression(e.expression);
    final staticType = expr.type;

    // Tell the generator to add a .toString() call if this expression isn't a
    // string already.
    final needsToString =
        !typeSystem.isSubtypeOf(staticType, typeProvider.stringType);

    _currentChildren.add(ReactiveText(expr, needsToString));
  }
}

class _TypeSubstitution
    implements
        TypeVisitorWithArgument<DartType, Map<TypeParameterElement, DartType>> {
  const _TypeSubstitution();

  @override
  DartType visitFunctionType(
      FunctionType type, Map<TypeParameterElement, DartType> argument) {
    // todo: Support substituting function types
    return type;
  }

  @override
  DartType visitInterfaceType(
      InterfaceType type, Map<TypeParameterElement, DartType> argument) {
    return type.element.instantiate(
      typeArguments: [
        for (final arg in type.typeArguments)
          arg.acceptWithArgument(this, argument),
      ],
      nullabilitySuffix: type.nullabilitySuffix,
    );
  }

  @override
  DartType visitTypeParameterType(
      TypeParameterType type, Map<TypeParameterElement, DartType> argument) {
    assert(argument.containsKey(type.element));
    return argument[type.element]!;
  }

  // These don't need changes

  @override
  DartType visitDynamicType(
      DynamicType type, Map<TypeParameterElement, DartType> argument) {
    return type;
  }

  @override
  DartType visitNeverType(
      NeverType type, Map<TypeParameterElement, DartType> argument) {
    return type;
  }

  @override
  DartType visitVoidType(
      VoidType type, Map<TypeParameterElement, DartType> argument) {
    return type;
  }
}

class _FindComponents {
  final Resolver resolver;
  final DomFragment root;

  _FindComponents(this.resolver, this.root);

  Component inferComponent() {
    final rootScope = resolver.scope.scopes[resolver.scope.root]!;
    final variables = {
      for (final variable in rootScope.declaredVariables)
        variable.element: variable,
    };

    final body =
        rootScope.function.functionExpression.body as BlockFunctionBody;

    final resolved = _findFlowUpdates(variables, root, body.block.statements);

    return Component(
      resolved.subComponents,
      rootScope,
      root,
      resolved.flow,
      resolved.initializers,
      resolved.instanceFunctions,
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

    // Find flow instructions in the component's Dart code
    outer:
    for (final stmt in statements) {
      if (stmt is LabeledStatement) {
        final isReactiveLabel = stmt.labels.any((l) => l.label.name == r'$');

        if (isReactiveLabel) {
          final inner = stmt.statement;
          flows.add(
            Flow(_FindReferencedVariables.find(inner, variables),
                SideEffect(inner)),
          );
        }
      } else if (stmt is FunctionDeclarationStatement) {
        if (!stmt.functionDeclaration.name.name.startsWith(zapPrefix)) {
          functions.add(stmt);
        }
      } else {
        if (stmt is VariableDeclarationStatement) {
          // Filter out __zap__var_1 variables that have only been created to
          // analyze expressions used in the DOM.
          for (final variable in stmt.variables.variables) {
            if (variable.name.name.startsWith(zapPrefix)) {
              continue outer;
            }
            final zapVariable = variables[variable.declaredElement];
            if (zapVariable is DartCodeVariable && zapVariable.isProperty) {
              // We need to generate special code to initialize properties as
              // they can be set as constructor parameters too.
              initializers.add(InitializeProperty(zapVariable));
              continue outer;
            }
          }
        }

        initializers.add(InitializeStatement(stmt));
      }
    }

    // And also infer it from the DOM
    void processNode(ReactiveNode node) {
      if (node is ReactiveText) {
        final relevant = _FindReferencedVariables.find(
            node.expression.expression, variables);
        flows.add(Flow(relevant, ChangeText(node)));
      } else if (node is ReactiveElement) {
        for (final handler in node.eventHandlers) {
          final listener = handler.listener.expression;
          final listenerIsMutable =
              listener is! FunctionReference && listener is! FunctionExpression;

          final relevantVariables = listenerIsMutable
              ? _FindReferencedVariables.find(listener, variables)
              : <BaseZapVariable>{};
          flows.add(Flow(relevantVariables, RegisterEventHandler(handler)));
        }

        node.attributes.forEach((key, value) {
          final dependsOn = _FindReferencedVariables.find(
              value.backingExpression.expression, variables);
          flows.add(Flow(dependsOn, ApplyAttribute(node, key)));
        });

        node.children.forEach(processNode);
      } else if (node is ReactiveIf) {
        // Blocks in the if statement will be compiled to lightweight components
        // written into separate classes.
        // However, they don't have any initializer statements and user code.
        for (final when in node.whens) {
          final flow = _findFlowUpdates(variables, when, []);
          subComponents.add(ResolvedSubComponent(
              flow.subComponents, when.resolvedScope, when, flow.flow));
        }

        final otherwise = node.otherwise;
        if (otherwise != null) {
          final flow = _findFlowUpdates(variables, otherwise, []);
          subComponents.add(ResolvedSubComponent(flow.subComponents,
              otherwise.resolvedScope, otherwise, flow.flow));
        }

        // The if should be updated if any variable referenced in any condition
        // updates.
        final finder = _FindReferencedVariables(variables);
        for (final condition in node.conditions) {
          condition.expression.accept(finder);
        }

        flows.add(Flow(finder.found, UpdateIf(node)));
      } else if (node is ReactiveAsyncBlock) {
        final scope = node.fragment.resolvedScope;
        final snapshotVariable =
            scope.findForSubcomponent(SubcomponentVariableKind.asyncSnapshot)!;
        final localDeclarations = {snapshotVariable.element: snapshotVariable};

        final flow = _findFlowUpdates(
          {...variables, ...localDeclarations},
          node.fragment,
          [],
        );
        subComponents.add(ResolvedSubComponent(
            flow.subComponents, scope, node.fragment, flow.flow));

        flows.add(Flow(
          _FindReferencedVariables.find(node.expression.expression, variables),
          UpdateAsyncValue(node),
        ));
      } else {
        node.children.forEach(processNode);
      }
    }

    fragment.rootNodes.forEach(processNode);
    return _FlowAndCategorizedStatements(
        flows, functions, initializers, subComponents);
  }
}

class _FindReferencedVariables extends GeneralizingAstVisitor<void> {
  final Map<Element, BaseZapVariable> variables;
  final Set<BaseZapVariable> found = {};

  _FindReferencedVariables(this.variables);

  static Set<BaseZapVariable> find(
      AstNode node, Map<Element, BaseZapVariable> variables) {
    final visitor = _FindReferencedVariables(variables);
    node.accept(visitor);

    return visitor.found;
  }

  @override
  void visitIdentifier(Identifier node) {
    final element = node.staticElement;
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
  final Component component;

  ResolvedComponent(this.componentName, this.component);
}
