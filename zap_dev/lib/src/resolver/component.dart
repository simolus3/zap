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
    this.children,
    this.scope,
    this.fragment,
    this.flows,
  ) {
    fragment.owningComponent = this;

    for (final child in children) {
      if (child is ResolvedSubComponent) {
        child.parent = this;
      }
    }
  }
}

class Component extends ComponentOrSubcomponent {
  /// A list of statements to run in the body of the generated constructor.
  final List<ComponentInitializer> componentInitializers;
  final List<FunctionDeclarationStatement> instanceFunctions;
  final List<String?> usedSlots;

  Component(
    super.children,
    super.scope,
    super.fragment,
    super.flows,
    this.componentInitializers,
    this.instanceFunctions,
    this.usedSlots,
  );
}

class ResolvedSubComponent extends ComponentOrSubcomponent {
  ComponentOrSubcomponent? parent;

  /// Whether this component is created for a fragment mounted as a slot.
  ///
  /// This has an impact on how subcomponent of this fragment are created, as
  /// those are then descendants of the owner of the slot and not of [parent].
  final bool isMountedInSlot;

  ResolvedSubComponent(
    super.children,
    super.scope,
    super.fragment,
    super.flows, {
    this.isMountedInSlot = false,
  });
}

abstract class ComponentInitializer {}

/// Run a statement from the `<script>` tag in the component's constructor.
class InitializeStatement extends ComponentInitializer {
  final Statement dartStatement;
  final DartCodeVariable? initializedVariable;

  InitializeStatement(this.dartStatement, this.initializedVariable);
}

/// Run a side effect (a statement labelled `$`) for the first time.
///
/// This could be modelled as an [InitializeStatement], but referencing the
/// actual effect here allows us to extract the [SideEffect.statement] into a
/// method on the component, avoiding to emit the same code twice.
///
/// This effectively runs a `$` statement from the component's constructor.
class InitialSideEffect extends ComponentInitializer {
  final SideEffect effect;

  InitialSideEffect(this.effect);
}

/// Initialize a component variable annotated with `@prop` to the value passed
/// from the constructor.
class InitializeProperty extends ComponentInitializer {
  final BaseZapVariable variable;

  InitializeProperty(this.variable);
}
