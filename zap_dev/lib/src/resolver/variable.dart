import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

/// A variable declared in the Dart script of a component.
class Variable {
  static const _availableUpdateSlots = 53;

  /// Whether this variable is read by the DOM of the component.
  bool hasReactiveReads = false;

  /// Whether this variable is mutable.
  ///
  /// We need to track updates to mutable variables stored in the DOM.
  bool isMutable = false;

  final VariableDeclaration declaration;
  final VariableElement declaredElement;
  final bool isProp;
  final bool hasInitializer;

  int? _updateSlot;

  Variable(
      this.declaration, this.declaredElement, this.isProp, this.hasInitializer);

  /// An index for this variable when running updates.
  ///
  /// Updates are encoded as a bitmap.
  int? get updateSlot => _updateSlot;

  set updateSlot(int? value) {
    if (value == null) {
      _updateSlot = null;
    } else {
      _updateSlot = value % _availableUpdateSlots;
    }
  }

  int get updateBitmask => 1 << updateSlot!;

  bool get needsUpdateTracking => isMutable && hasReactiveReads;
}
