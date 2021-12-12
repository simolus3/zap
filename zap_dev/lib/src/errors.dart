import 'package:source_span/source_span.dart';

import 'preparation/ast.dart';

class ZapError {
  final String message;
  final FileSpan? span;

  ZapError(this.message, this.span);

  factory ZapError.onNode(AstNode node, String message) {
    return ZapError(message, null);
  }

  String humanReadableDescription() {
    return span?.message(message, color: 'red') ?? message;
  }

  @override
  String toString() {
    return 'ZapError: $message';
  }
}

abstract class ErrorReporter {
  factory ErrorReporter(void Function(ZapError error) handler) =
      _FunctionReporter;

  void reportError(ZapError error);
}

class _FunctionReporter implements ErrorReporter {
  final void Function(ZapError) _handler;

  _FunctionReporter(this._handler);

  @override
  void reportError(ZapError error) {
    return _handler(error);
  }
}
