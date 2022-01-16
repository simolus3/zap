import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:build/build.dart';
import 'package:source_span/source_span.dart';

import '../../preparation/ast.dart';
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

  bool isString(DartType type) {
    return typeSystem.isAssignableTo(type, typeProvider.stringType);
  }

  DartType checkFuture(DartType shouldBeFuture, FileSpan? span) {
    return _extractSingleType(shouldBeFuture, span, typeProvider.futureElement,
        'This must be a future!');
  }

  DartType checkStream(DartType shouldBeStream, FileSpan? span) {
    return _extractSingleType(shouldBeStream, span, typeProvider.streamElement,
        'This must be a stream!');
  }

  DartType checkIterable(DartType shouldBeIterable, FileSpan? span) {
    return _extractSingleType(shouldBeIterable, span,
        typeProvider.iterableElement, 'This must be an iterable!');
  }

  DartType _extractSingleType(
      DartType type, FileSpan? span, ClassElement element, String description) {
    final asStream = type.asInstanceOf(element);
    if (asStream == null) {
      errors.reportError(ZapError(description, span));
      return typeProvider.dynamicType;
    }

    return asStream.typeArguments.single;
  }

  EventCheckingResult checkEvent(
      Attribute attribute, String eventName, Expression expression) {
    final staticType = expression.staticType ?? typeProvider.dynamicType;
    final event = domTypes.knownEvents[eventName];
    final eventType = domTypes.dartTypeForEvent(eventName) ?? domTypes.event;

    if (event == null) {
      errors.reportError(ZapError(
          'Unknown event `$eventName`, this may cause runtime errors',
          attribute.keyToken?.span));
    }

    if (staticType is! FunctionType) {
      errors.reportError(ZapError('Not a function!', attribute.value?.span));
      return EventCheckingResult(true, event);
    }

    final parameters = staticType.parameters;
    if (parameters.length > 1) {
      errors.reportError(ZapError(
          'Event handlers must have at most one parameter!',
          attribute.value?.span));
      return EventCheckingResult(true, event);
    }

    if (parameters.isEmpty) {
      return EventCheckingResult(true, event);
    }

    final parameter = parameters.single;
    if (parameter.isNamed) {
      errors.reportError(
        ZapError('The parameter on the callback must be positional',
            attribute.value?.span),
      );
    }

    if (!typeSystem.isSubtypeOf(eventType, parameter.type)) {
      final expectedType = eventType.getDisplayString(withNullability: true);

      errors.reportError(ZapError(
        'The function must accept a $expectedType from `dart.html`',
        attribute.value?.span,
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
  final DomEventType? known;

  EventCheckingResult(this.dropParameter, this.known);
}
