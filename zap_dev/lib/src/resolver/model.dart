import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'flow.dart';
import 'reactive_dom.dart';
import 'variable.dart';

abstract class ComponentOrFragment {
  List<ReactiveNode> get root;
  List<Flow> get updateEvents;
}

class ResolvedComponent implements ComponentOrFragment {
  final Map<Element, Variable> dartDeclarations;
  final List<ExecutableElement> dartFunctions;
  @override
  final List<ReactiveNode> root;
  final List<ComponentInitializer> componentInitializers;
  final List<FunctionDeclarationStatement> instanceFunctions;
  @override
  final List<Flow> updateEvents;

  final ParameterElement? self;

  ResolvedComponent(
    this.dartDeclarations,
    this.dartFunctions,
    this.root,
    this.componentInitializers,
    this.instanceFunctions,
    this.updateEvents,
    this.self,
  );
}

class SubFragment implements ComponentOrFragment {
  @override
  final List<ReactiveNode> root;
  @override
  final List<Flow> updateEvents;

  SubFragment(this.root, this.updateEvents);
}

extension AllNodes on ComponentOrFragment {
  Iterable<ReactiveNode> get allNodes {
    return root.expand((e) => e.selfAndAllDescendants);
  }
}

abstract class ComponentInitializer {}

class InitializeStatement extends ComponentInitializer {
  final Statement dartStatement;

  InitializeStatement(this.dartStatement);
}

class InitializeProperty extends ComponentInitializer {
  final Variable variable;

  InitializeProperty(this.variable);
}
