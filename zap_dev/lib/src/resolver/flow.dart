import 'package:analyzer/dart/ast/ast.dart';

import 'dart.dart';
import 'reactive_dom.dart';

class Flow {
  final Set<BaseZapVariable> dependencies;
  final Action action;

  Iterable<BaseZapVariable> get _mutableDependencies =>
      dependencies.where((dep) => dep.isMutable);

  Flow(this.dependencies, this.action);

  bool get isOneOffAction => _mutableDependencies.isEmpty;

  int get bitmask {
    return _mutableDependencies.fold(
        0, (prev, variable) => prev | variable.updateBitmask);
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

class UpdateIf extends Action {
  final ReactiveIf node;

  UpdateIf(this.node);
}

class UpdateAsyncValue extends Action {
  final ReactiveAsyncBlock block;

  UpdateAsyncValue(this.block);
}
