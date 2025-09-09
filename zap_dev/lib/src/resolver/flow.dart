import 'package:analyzer/dart/ast/ast.dart';

import 'dart.dart';
import 'reactive_dom.dart';

class Flow {
  final Set<HasUpdateMask> dependencies;
  final Action action;

  Iterable<HasUpdateMask> get _mutableDependencies => dependencies.where((dep) {
    if (dep is BaseZapVariable) {
      return dep.isMutable;
    } else if (dep is WatchedExpression) {
      return true;
    } else {
      throw AssertionError('Uknown flow dependency');
    }
  });

  Flow(this.dependencies, this.action);

  bool get isOneOffAction => _mutableDependencies.isEmpty;

  int get bitmask {
    return _mutableDependencies.fold(
      0,
      (prev, variable) => prev | variable.updateBitmask,
    );
  }
}

/// An imperative action to run in response to a component being created or
/// some variables changing.
///
/// All actions are dispatched asynchronously by scheduling a microtask for
/// a variable update.
abstract class Action {}

/// Runs a statement in response to variables changing.
///
/// A [SideEffect] is created from the `$` syntax in components:
///
/// ```dart
/// var username = 'Name';
///
/// $: window.document.title = username;
/// ```
class SideEffect extends Action {
  final Statement statement;

  SideEffect(this.statement);
}

/// Changes the text content of a [ReactiveText] DOM node.
class ChangeText extends Action {
  final ReactiveText text;

  ChangeText(this.text);
}

/// Creates, or changes, an event handler for a node and a specific event.
class RegisterEventHandler extends Action {
  final EventHandler handler;

  RegisterEventHandler(this.handler);
}

/// Change, add or remove an attribute from a node.
class ApplyAttribute extends Action {
  final ReactiveElement element;
  final String name;

  ApplyAttribute(this.element, this.name);
}

class ApplyBinding extends Action {
  final ReactiveElement element;
  final BindProperty binding;

  ApplyBinding(this.element, this.binding);
}

class ChangePropertyOfSubcomponent extends Action {
  final SubComponent subcomponent;
  final String property;

  ChangePropertyOfSubcomponent(this.subcomponent, this.property);
}

/// An instruction to:
///
/// - update the condition of an [ReactiveIf].
/// - the stream or future listened to by an [ReactiveAsyncBlock].
/// - the iterable of a [ReactiveFor].
/// - the value of a [ReactiveKeyBlock].
/// - the raw HTML expression of a [ReactiveRawHtml] tag.

class UpdateBlockExpression extends Action {
  final ReactiveNode block;

  UpdateBlockExpression(this.block);
}

/// Update the source of a `watch()` call.
///
/// This is used when the expression being watched is itself mutable.
class UpdateWatchable extends Action {
  final WatchedExpression watched;

  UpdateWatchable(this.watched);
}

/// Update a variable that used a `watch()` call in its initializer.
///
/// When the value of the watched expression changes, so should the variable.
class ReEvaluateVariableWithWatchInitializer extends Action {
  final DartCodeVariable variable;

  ReEvaluateVariableWithWatchInitializer(this.variable);
}
