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
  final List<String?> usedSlots;

  Component(
    List<ComponentOrSubcomponent> children,
    ZapVariableScope scope,
    DomFragment fragment,
    List<Flow> flows,
    this.componentInitializers,
    this.instanceFunctions,
    this.usedSlots,
  ) : super(children, scope, fragment, flows);
}

class ResolvedSubComponent extends ComponentOrSubcomponent {
  ComponentOrSubcomponent? parent;

  /// Whether this component is created for a fragment mounted as a slot.
  ///
  /// This has an impact on how subcomponent of this fragment are created, as
  /// those are then descendants of the owner of the slot and not of [parent].
  final bool isMountedInSlot;

  ResolvedSubComponent(
    List<ComponentOrSubcomponent> children,
    ZapVariableScope scope,
    DomFragment fragment,
    List<Flow> flows, {
    this.isMountedInSlot = false,
  }) : super(children, scope, fragment, flows);
}

abstract class ComponentInitializer {}

class InitializeStatement extends ComponentInitializer {
  final Statement dartStatement;
  final DartCodeVariable? initializedVariable;

  InitializeStatement(this.dartStatement, this.initializedVariable);
}

class InitializeProperty extends ComponentInitializer {
  final BaseZapVariable variable;

  InitializeProperty(this.variable);
}
