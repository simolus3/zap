import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:build/build.dart';
import 'package:source_span/source_span.dart';

import '../../ast.dart';
import '../../errors.dart';
import 'dom_types.dart';

class TypeChecker {
  /// `dart:html` is the same for everyone and changes to the Dart SDK
  /// invalidate the entire build. So, we can share information resolved from
  /// the SDK across build steps.
  static Completer<ResolvedDomTypes>? _domCompleter;

  final TypeProvider typeProvider;
  final TypeSystem typeSystem;
  final ResolvedDomTypes domTypes;
  final ErrorReporter errors;

  TypeChecker._(this.typeProvider, this.typeSystem, this.domTypes, this.errors);

  DartType checkFuture(DartType shouldBeFuture, FileSpan? span) {
    final asFuture = shouldBeFuture.asInstanceOf(typeProvider.futureElement);
    if (asFuture == null) {
      errors.reportError(ZapError('This must be a future!', span));
      return typeProvider.dynamicType;
    }

    return asFuture.typeArguments.single;
  }

  DartType checkStream(DartType shouldBeStream, FileSpan? span) {
    final asStream = shouldBeStream.asInstanceOf(typeProvider.streamElement);
    if (asStream == null) {
      errors.reportError(ZapError('This must be a stream!', span));
      return typeProvider.dynamicType;
    }

    return asStream.typeArguments.single;
  }

  EventCheckingResult checkEvent(
      Attribute attribute, String eventName, Expression expression) {
    final staticType = expression.staticType ?? typeProvider.dynamicType;
    final event = knownEvents[eventName];
    final eventType = domTypes.dartTypeForEvent(eventName) ?? domTypes.event;

    if (event == null) {
      errors.reportError(ZapError(
          'Unknown event `$eventName`, this may cause runtime errors',
          attribute.valueSpan));
    }

    if (staticType is! FunctionType) {
      errors.reportError(ZapError('Not a function!', attribute.valueSpan));
      return EventCheckingResult(true, event);
    }

    final parameters = staticType.parameters;
    if (parameters.length > 1) {
      errors.reportError(ZapError(
          'Event handlers must have at most one parameter!',
          attribute.valueSpan));
      return EventCheckingResult(true, event);
    }

    if (parameters.isEmpty) {
      return EventCheckingResult(true, event);
    }

    final parameter = parameters.single;
    if (parameter.isNamed) {
      errors.reportError(
        ZapError('The parameter on the callback must be positional',
            attribute.valueSpan),
      );
    }

    if (!typeSystem.isSubtypeOf(eventType, parameter.type)) {
      final expectedType = eventType.getDisplayString(withNullability: true);

      errors.reportError(ZapError(
        'The function must accept a $expectedType from `dart.html`',
        attribute.valueSpan,
      ));
    }

    return EventCheckingResult(false, event);
  }

  static Future<TypeChecker> checkerFor(TypeProvider provider, TypeSystem ts,
      ErrorReporter errors, BuildStep buildStep) async {
    return TypeChecker._(provider, ts, await _resolveTypes(buildStep), errors);
  }

  static Future<ResolvedDomTypes> _resolveTypes(BuildStep step) {
    if (_domCompleter != null) {
      return _domCompleter!.future;
    } else {
      final completer = _domCompleter = Completer.sync()
        ..complete(
          () async {
            LibraryElement? dartHtml;
            await for (final lib in step.resolver.libraries) {
              if (lib.name.contains('dart.') && lib.name.contains('html')) {
                dartHtml = lib;
              }
            }

            return ResolvedDomTypes(dartHtml!);
          }(),
        );

      return completer.future;
    }
  }
}

class EventCheckingResult {
  final bool dropParameter;
  final KnownEventType? known;

  EventCheckingResult(this.dropParameter, this.known);
}
