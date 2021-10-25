import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';

import '../ast.dart' as zap;
import '../errors.dart';
import '../utils/dart.dart';
import 'external_component.dart';
import 'flow.dart';
import 'model.dart';
import 'preparation.dart';
import 'reactive_dom.dart';
import 'types/checker.dart';
import 'types/dom_types.dart';
import 'variable.dart';

Future<ResolvedComponent> resolveComponent(
  PrepareResult prepare,
  LibraryElement preparedLibrary,
  CompilationUnit preparedUnit,
  ErrorReporter errorReporter,
  BuildStep buildStep,
) async {
  // We always prepare a single file with a top-level function to analyze.
  final root = preparedUnit.declarations.single as FunctionDeclaration;
  final resolver = _FindAndAnalyzeVariableResolver(root);
  resolver.visitCompilationUnit(preparedUnit);

  final typeProvider = preparedLibrary.typeProvider;
  final typeSystem = preparedLibrary.typeSystem;

  final checker = await TypeChecker.checkerFor(
      typeProvider, typeSystem, errorReporter, buildStep);

  final translator = _DomTranslator(
    prepare,
    _findExternalComponents(preparedLibrary),
    preparedUnit,
    root,
    errorReporter,
    typeProvider,
    typeSystem,
    checker,
  );
  prepare.component.accept(translator, null);

  final body = root.functionExpression.body as BlockFunctionBody;
  final statements = body.block.statements;

  final flowAndStmts = _findFlowUpdates(
      resolver.foundVariables, translator._currentChildren, statements);

  // Mark all variables read in a flow
  for (final flow in flowAndStmts.flow) {
    for (final variable in flow.dependencies) {
      variable.hasReactiveReads = true;
    }
  }

  // Assign update slots to mutable, reactive variables
  var i = 0;
  for (final variable in resolver.foundVariables.values) {
    if (variable.needsUpdateTracking) {
      variable.updateSlot = i++;
    }
  }

  return ResolvedComponent(
    resolver.foundVariables,
    resolver.definedFunctions,
    translator._currentChildren,
    flowAndStmts.initializers,
    flowAndStmts.instanceFunctions,
    flowAndStmts.flow,
    resolver.self,
  );
}

List<ExternalComponent> _findExternalComponents(LibraryElement library) {
  final components = <ExternalComponent>[];

  library.importedLibraries
      .map((l) => l.exportNamespace)
      .fold<Map<String, Element>>(
          <String, Element>{},
          (names, ns) =>
              names..addAll(ns.definedNames)).forEach((name, element) {
    if (element is ClassElement && isComponent(element)) {
      components.add(_readComponent(name, element));
    }
  });

  return components;
}

ExternalComponent _readComponent(String name, ClassElement element) {
  final parameters = <MapEntry<String, DartType>>[];

  for (final accessor in element.fields) {
    parameters.add(MapEntry(accessor.name, accessor.type));
  }

  // Note: We're not using element.name since the name may be aliased.
  return ExternalComponent(name, parameters);
}

class _FindAndAnalyzeVariableResolver extends RecursiveAstVisitor<void> {
  var _isInDomExpression = false;

  final AstNode root;
  var _isInRoot = true;

  final Map<Element, Variable> foundVariables = {};
  final List<ExecutableElement> definedFunctions = [];
  ParameterElement? self;

  _FindAndAnalyzeVariableResolver(this.root);

  Variable? _variableFor(Element element) {
    if (element is VariableElement) {
      return foundVariables[element];
    } else if (element is PropertyAccessorElement) {
      return foundVariables[element.variable];
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final inRootBefore = _isInRoot;
    _isInRoot = node == root;

    final element = node.declaredElement;
    if (element != null && element.name != componentFunctionWrapper) {
      definedFunctions.add(element);
    }

    if (_isInRoot) {
      // Read the element for the "ComponentOrPending" parameter added to the
      // helper code.
      self = node.functionExpression.parameters?.parameterElements.single;
    }

    super.visitFunctionDeclaration(node);

    _isInRoot = inRootBefore;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.name.startsWith(zapPrefix)) {
      // Variables with __zap__ are actually inserted to analyze inline
      // expressions in the component, they don't introduce variables that
      // could be referenced.
      _isInDomExpression = true;
    } else {
      if (_isInRoot) {
        final resolved = node.declaredElement;
        if (resolved != null) {
          foundVariables.putIfAbsent(
              resolved,
              () => Variable(
                  node, resolved, isProp(resolved), node.initializer != null));
        }
      }
    }

    super.visitVariableDeclaration(node);
  }

  void _markMutable(Element? target) {
    if (target != null) {
      _variableFor(target)?.isMutable = true;
    }
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    super.visitAssignmentExpression(node);

    _markMutable(node.writeElement);
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

    if (_isInDomExpression && staticElement != null) {
      _variableFor(staticElement)?.hasReactiveReads = true;
    }
  }
}

class _DomTranslator extends zap.AstVisitor<void, void> {
  static final _eventRegex = RegExp(r'^on:(\w+)(?:\|(\w+))*$');

  final PrepareResult prepareResult;
  final List<ExternalComponent> components;
  final CompilationUnit resolved;
  final FunctionDeclaration root;

  final ErrorReporter errors;
  final TypeProvider provider;
  final TypeSystem typeSystem;
  final TypeChecker zapChecker;

  _DomTranslator(this.prepareResult, this.components, this.resolved, this.root,
      this.errors, this.provider, this.typeSystem, this.zapChecker);

  List<ReactiveNode> _currentChildren = [];

  Expression _resolveExpression(String lexeme) {
    final name = prepareResult.introducedDartExpressions[lexeme]!;
    final body = root.functionExpression.body as BlockFunctionBody;
    final children = body.block.childEntities.whereType<AstNode>();

    final declaration = children.firstWhere((element) {
      if (element is VariableDeclarationStatement) {
        return element.variables.variables.any((v) => v.name.name == name);
      }

      return false;
    }) as VariableDeclarationStatement;

    return declaration.variables.variables.single.initializer!;
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
          (attribute.value as zap.WrappedDartExpression)
              .expression
              .dartExpression);

      final eventMatch = _eventRegex.firstMatch(key);
      if (eventMatch != null) {
        // This attribute uses the `on:` syntax to listen for events.
        final name = eventMatch.group(1)!;
        final modifiers = List.generate(eventMatch.groupCount - 1,
                (index) => eventMatch.group(index + 1)!)
            .map(parseEventModifier)
            .whereType<EventModifier>()
            .toSet();

        final checkResult = zapChecker.checkEvent(attribute, name, value);
        handlers.add(EventHandler(name, checkResult.known, modifiers, value,
            checkResult.dropParameter));
      } else {
        // A regular attribute it is then.
        final type = value.staticType ?? provider.dynamicType;
        AttributeMode mode;
        if (typeSystem.isPotentiallyNullable(type)) {
          mode = AttributeMode.setIfNotNullClearOtherwise;
        } else if (typeSystem.isAssignableTo(type, provider.boolType)) {
          mode = AttributeMode.addIfTrue;
        } else {
          mode = AttributeMode.setValue;
        }

        attributes[key] = ReactiveAttribute(value, mode);
      }
    }

    final external = components
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
    final conditions = <Expression>[];
    final whens = <List<ReactiveNode>>[];
    List<ReactiveNode>? otherwise;

    Expression checkBoolean(zap.DartExpression dart) {
      final condition = _resolveExpression(dart.dartExpression);
      final type = condition.staticType ?? provider.dynamicType;
      if (!typeSystem.isSubtypeOf(type, provider.boolType)) {
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

    _currentChildren.add(ReactiveIf(conditions, whens, otherwise));
  }

  @override
  void visitText(zap.Text e, void arg) {
    _currentChildren.add(ConstantText(e.text));
  }

  @override
  void visitWrappedDartExpression(zap.WrappedDartExpression e, void arg) {
    final expr = _resolveExpression(e.expression.dartExpression);
    final staticType = expr.staticType;

    // Tell the generator to add a .toString() call if this expression isn't a
    // string already.
    final needsToString = staticType == null ||
        !typeSystem.isSubtypeOf(staticType, provider.stringType);

    _currentChildren.add(ReactiveText(expr, needsToString));
  }
}

_FlowAndCategorizedStatements _findFlowUpdates(
  Map<Element, Variable> variables,
  List<ReactiveNode> rootNodes,
  List<Statement> statements,
) {
  final flows = <Flow>[];
  final functions = <FunctionDeclarationStatement>[];
  final initializers = <ComponentInitializer>[];

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
      functions.add(stmt);
    } else {
      if (stmt is VariableDeclarationStatement) {
        // Filter out __zap__var_1 variables that have only been created to
        // analyze expressions used in the DOM.
        for (final variable in stmt.variables.variables) {
          if (variable.name.name.startsWith(zapPrefix)) {
            continue outer;
          }
          final zapVariable = variables[variable.declaredElement];
          if (zapVariable != null && zapVariable.isProp) {
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
      final relevant =
          _FindReferencedVariables.find(node.expression, variables);
      flows.add(Flow(relevant, ChangeText(node)));
    } else if (node is ReactiveElement) {
      for (final handler in node.eventHandlers) {
        final listener = handler.listener;
        final listenerIsMutable =
            listener is! FunctionReference && listener is! FunctionExpression;

        final relevantVariables = listenerIsMutable
            ? _FindReferencedVariables.find(listener, variables)
            : <Variable>{};
        flows.add(Flow(relevantVariables, RegisterEventHandler(handler)));
      }

      node.attributes.forEach((key, value) {
        final dependsOn =
            _FindReferencedVariables.find(value.backingExpression, variables);
        flows.add(Flow(dependsOn, ApplyAttribute(node, key)));
      });

      node.children.forEach(processNode);
    } else if (node is ReactiveIf) {
      final whenFragments = <SubFragment>[];

      // Blocks in the if statement will be compiled to lightweight components
      // written into separate classes.
      // However, they don't have any initializer statements and user code.
      for (final when in node.whens) {
        final flow = _findFlowUpdates(variables, when, []);
        whenFragments.add(SubFragment(when, flow.flow));
      }
      node.fragmentsForWhen = whenFragments;

      final otherwise = node.otherwise;
      if (otherwise != null) {
        final flow = _findFlowUpdates(variables, otherwise, []);
        node.fragmentForOtherwise = SubFragment(otherwise, flow.flow);
      }

      // The if should be updated if any variable referenced in any condition
      // updates.
      final finder = _FindReferencedVariables(variables);
      for (final condition in node.conditions) {
        condition.accept(finder);
      }

      flows.add(Flow(finder.found, UpdateIf(node)));
    } else {
      node.children.forEach(processNode);
    }
  }

  rootNodes.forEach(processNode);
  return _FlowAndCategorizedStatements(flows, functions, initializers);
}

class _FindReferencedVariables extends GeneralizingAstVisitor<void> {
  final Map<Element, Variable> variables;
  final Set<Variable> found = {};

  _FindReferencedVariables(this.variables);

  static Set<Variable> find(AstNode node, Map<Element, Variable> variables) {
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

  _FlowAndCategorizedStatements(
      this.flow, this.instanceFunctions, this.initializers);
}
