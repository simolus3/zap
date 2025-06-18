import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';

class ZapVariableScope {
  final List<BaseZapVariable> declaredVariables = [];
  final List<ZapVariableScope> childScopes = [];
  ZapVariableScope? parent;

  final FunctionDeclaration? function;
  final List<ResolvedDartExpression> usedDartExpressions = [];

  ZapVariableScope(this.function);

  SubcomponentVariable? findForSubcomponent(SubcomponentVariableKind kind) {
    return declaredVariables.whereType<SubcomponentVariable>().firstWhereOrNull(
      (v) => v.kind == kind,
    );
  }
}

abstract class HasUpdateMask {
  /// An index for this variable when running updates.
  ///
  /// Updates are encoded as a bitmap.
  int? get updateSlot;
  set updateSlot(int? value);
}

extension UpdateBitmask on HasUpdateMask {
  int get updateBitmask => 1 << updateSlot!;
}

/// Base class for variables that can be used in the DOM part of a zap
/// component.
abstract class BaseZapVariable implements HasUpdateMask {
  /// The amount of individual bits we can control with JavaScript numbers.
  static const _availableUpdateSlots = 53;

  /// The scope or component where this variable was declared.
  final ZapVariableScope scope;

  /// Whether this variable is mutated somewhere.
  ///
  /// We can generate more efficient code for immutable expressions, so we don't
  /// want to consider a variable mutable just because it doesn't have a
  /// `final` modifier. Instead, we set this field to `true` as soon as we find
  /// a matching assignment.
  bool isMutable = false;

  /// Whether this variable is read in any [ResolvedDartExpression] appearing in
  /// the components DOM tree.
  ///
  /// We need to track updates to variables that are mutable and used in the
  /// DOM.
  bool isInReactiveRead = false;

  /// The synthetic Dart construct backing this variable.
  AstNode get declaration;

  /// The [Element] created by the [declaration].
  PromotableElement get element;

  /// The resolved type of this variable.
  DartType get type => element.type;

  int? _updateSlot;

  BaseZapVariable._(this.scope);

  @override
  int? get updateSlot => _updateSlot;

  @override
  set updateSlot(int? value) {
    if (value == null) {
      _updateSlot = null;
    } else {
      _updateSlot = value % _availableUpdateSlots;
    }
  }

  bool get needsUpdateTracking => isMutable && isInReactiveRead;
}

/// A variable declared as a top-level statement in a zap `<script>`.
///
/// The [scope] of such variables is always the top-level scope associated with
/// the root component.
class DartCodeVariable extends BaseZapVariable {
  @override
  final VariableDeclaration declaration;
  @override
  final LocalVariableElement element;

  /// Whether this variable was declared as a `@prop` that can be set by outer
  /// components.
  final bool isProperty;

  final ResolvedDartExpression? initializer;

  bool get isLate => element.isLate;

  DartCodeVariable({
    required ZapVariableScope scope,
    required this.declaration,
    required this.element,
    this.isProperty = false,
    this.initializer,
  }) : super._(scope) {
    if (isProperty) {
      // Properties are always mutable.
      isMutable = true;
    }
  }
}

/// A variable introduced by a specific component, such as an `async` or `for`
/// block.
///
/// For example:
///
///  - in `{await each snapshot from stream} {/await}`, `snapshot` is a variable
///    bound to the result of the snapshot.
///  - in `{for element in it}`, `element` is a variable bound to the element
///    iterable for which the subcomponent is rendered.
class SubcomponentVariable extends BaseZapVariable {
  @override
  final AstNode declaration;
  @override
  final LocalVariableElement element;
  final SubcomponentVariableKind kind;

  @override
  final DartType type;

  SubcomponentVariable({
    required ZapVariableScope scope,
    required this.declaration,
    required this.type,
    required this.element,
    required this.kind,
  }) : super._(scope);
}

/// The `self` keyword, which refers to the component being rendered.
class SelfReference extends BaseZapVariable {
  @override
  final FormalParameter declaration;
  @override
  final ParameterElement element;

  SelfReference(super.scope, this.declaration, this.element) : super._();
}

class ResolvedDartExpression {
  final Expression expression;
  final ZapVariableScope scope;

  final DartType staticType;

  /// All expressions watched in this expression.
  List<WatchedExpression> watched = [];

  ResolvedDartExpression(
    this.expression,
    this.scope, {
    required DartType dynamic,
  }) : staticType = expression.staticType ?? dynamic {
    scope.usedDartExpressions.add(this);
  }
}

class WatchedExpression implements HasUpdateMask {
  final ResolvedDartExpression expression;

  WatchedExpression(this.expression);

  @override
  int? updateSlot;
}

enum SubcomponentVariableKind { asyncSnapshot, forBlockElement, forBlockIndex }
