import 'package:analyzer/dart/ast/ast.dart';

import 'dart.dart';
import 'flow.dart';
import 'reactive_dom.dart';

abstract class ComponentOrSubcomponent {
  final List<ComponentOrSubcomponent> children;
  final ZapVariableScope scope;
  final DomFragment fragment;
  final List<Flow> flows;

  ComponentOrSubcomponent(
      this.children, this.scope, this.fragment, this.flows) {
    scope.owningComponent = this;
    fragment.owningComponent = this;

    for (final child in children) {
      if (child is ResolvedSubComponent) {
        child.parent = this;
      }
    }
  }
}

class Component extends ComponentOrSubcomponent {
  final List<ComponentInitializer> componentInitializers;
  final List<FunctionDeclarationStatement> instanceFunctions;

  Component(
    List<ComponentOrSubcomponent> children,
    ZapVariableScope scope,
    DomFragment fragment,
    List<Flow> flows,
    this.componentInitializers,
    this.instanceFunctions,
  ) : super(children, scope, fragment, flows);
}

class ResolvedSubComponent extends ComponentOrSubcomponent {
  ComponentOrSubcomponent? parent;

  ResolvedSubComponent(
    List<ComponentOrSubcomponent> children,
    ZapVariableScope scope,
    DomFragment fragment,
    List<Flow> flows,
  ) : super(children, scope, fragment, flows);
}

abstract class ComponentInitializer {}

class InitializeStatement extends ComponentInitializer {
  final Statement dartStatement;

  InitializeStatement(this.dartStatement);
}

class InitializeProperty extends ComponentInitializer {
  final BaseZapVariable variable;

  InitializeProperty(this.variable);
}
