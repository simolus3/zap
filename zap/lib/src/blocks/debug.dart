import 'dart:developer';
import 'dart:html';

import '../core/fragment.dart';

/// Implementation of the `{@debug x1, x2, ...}` tag.
class DebugTag extends Fragment {
  /// A textual description of the source location where this `{@debug}` tag
  /// occurs.
  final String sourceLocation;

  /// The variable names watched in this debug tag.
  final List<String> variableNames;

  final List<Object?> _knownValues;

  DebugTag(this.sourceLocation, this.variableNames)
      : _knownValues = List.filled(variableNames.length, null);

  set expressions(List<Object?> expressions) {
    assert(expressions.length == variableNames.length,
        'Unexpected length of expressions to check');

    var different = false;
    for (var i = 0; i < expressions.length; i++) {
      if (_knownValues[i] != expressions[i]) {
        different = true;
        _knownValues[i] = expressions[i];
      }
    }

    if (different) {
      final msg = StringBuffer();
      for (var i = 0; i < expressions.length; i++) {
        if (i != 0) {
          msg.write(', ');
        }

        msg.write('${variableNames[i]}: ${expressions[i]}');
      }

      print(msg);
      debugger(message: 'Paused at @debug tag for $sourceLocation');
    }
  }

  @override
  void create() {}

  @override
  void destroy() {}

  @override
  void mount(Element target, [Node? anchor]) {}

  @override
  void update(int delta) {}
}
