import 'package:analyzer/dart/element/type.dart';

import 'component.dart';
import 'dart.dart';
import 'external_component.dart';
import 'types/dom_types.dart';

class DomFragment {
  final List<ReactiveNode> rootNodes;
  final ZapVariableScope resolvedScope;

  ComponentOrSubcomponent? owningComponent;

  DomFragment(this.rootNodes, this.resolvedScope);

  Iterable<ReactiveNode> get allNodes {
    return rootNodes.expand((e) => e.selfAndAllDescendants);
  }
}

abstract class ReactiveNode {
  Iterable<ReactiveNode> get children;

  Iterable<ReactiveNode> get allDescendants {
    return children.expand((element) => element.selfAndAllDescendants);
  }

  Iterable<ReactiveNode> get selfAndAllDescendants {
    return [this].followedBy(allDescendants);
  }
}

class ReactiveElement extends ReactiveNode {
  final String tagName;
  final KnownElementInfo? knownElement;

  /// Constant attributes are expressed as Dart string literals.
  final Map<String, ReactiveAttribute> attributes;
  final List<EventHandler> eventHandlers;
  final List<ElementBinder> binders;

  @override
  final List<ReactiveNode> children;

  ReactiveElement(this.tagName, this.knownElement, this.attributes,
      this.eventHandlers, this.children, this.binders) {
    for (final handler in eventHandlers) {
      handler.parent = this;
    }
  }
}

/// Mount a slot into the DOM of a component.
///
/// Slots can be set by parent components.
class MountSlot extends ReactiveNode {
  /// If this refers to a named slot, this is that name.
  ///
  /// Otherwise, the unnamed slot is mounted here.
  final String? slotName;
  final DomFragment defaultContent;

  MountSlot(this.slotName, this.defaultContent);

  @override
  Iterable<ReactiveNode> get children => const Iterable.empty();
}

class ReactiveRawHtml extends ReactiveNode {
  final ResolvedDartExpression expression;
  final bool needsToString;

  ReactiveRawHtml({required this.expression, required this.needsToString});

  @override
  Iterable<ReactiveNode> get children => const Iterable.empty();
}

abstract class ReactiveBlock extends ReactiveNode {
  @override
  Iterable<ReactiveNode> get children => const Iterable.empty();
}

class ReactiveIf extends ReactiveBlock {
  final List<ResolvedDartExpression> conditions;
  final List<DomFragment> whens;
  final DomFragment? otherwise;

  ReactiveIf(this.conditions, this.whens, this.otherwise);
}

class ReactiveFor extends ReactiveBlock {
  /// The iterable this for block is iterating over.
  final ResolvedDartExpression expression;
  final DartType elementType;

  final DomFragment fragment;

  ReactiveFor(this.expression, this.elementType, this.fragment);
}

class ReactiveAsyncBlock extends ReactiveBlock {
  final bool isStream;
  final DartType type;
  final ResolvedDartExpression expression;

  final DomFragment fragment;

  ReactiveAsyncBlock({
    required this.isStream,
    required this.type,
    required this.expression,
    required this.fragment,
  });
}

class ReactiveKeyBlock extends ReactiveBlock {
  final ResolvedDartExpression expression;
  final DomFragment fragment;

  ReactiveKeyBlock(this.expression, this.fragment);
}

class ReactiveAttribute {
  final ResolvedDartExpression backingExpression;
  final AttributeMode mode;

  ReactiveAttribute(this.backingExpression, this.mode);
}

enum AttributeMode {
  setValue,
  addIfTrue,
  setIfNotNullClearOtherwise,
}

class SubComponent extends ReactiveNode {
  final ExternalComponent component;
  final Map<String, ResolvedDartExpression> expressions;

  final DomFragment? defaultSlot;
  final Map<String, DomFragment> slots;

  SubComponent({
    required this.component,
    required this.expressions,
    this.defaultSlot,
    this.slots = const {},
  });

  @override
  Iterable<ReactiveNode> get children => [];
}

/// Renders the [expression], which should evaluate to a `ZapComponent`, as a
/// subcomponent.
class DynamicSubComponent extends ReactiveBlock {
  final ResolvedDartExpression expression;

  DynamicSubComponent(this.expression);
}

class ConstantText extends ReactiveNode {
  final String text;

  ConstantText(this.text);

  @override
  Iterable<ReactiveNode> get children => const Iterable.empty();
}

class ReactiveText extends ReactiveNode {
  final ResolvedDartExpression expression;
  final bool needsToString;

  ReactiveText(this.expression, this.needsToString);

  @override
  Iterable<ReactiveNode> get children => const Iterable.empty();
}

enum EventModifier {
  preventDefault,
  stopPropagation,
  passive,
  nonpassive,
  capture,
  once,
  self,
  trusted,
}

class EventHandler {
  final String event;
  final KnownEventType? knownType;
  final Set<EventModifier> modifier;
  final ResolvedDartExpression listener;
  final bool isNoArgsListener;

  late ReactiveElement parent;

  String get effectiveEventType => knownType?.type ?? 'Event';

  bool get isCapturing => modifier.contains(EventModifier.capture);

  EventHandler(this.event, this.knownType, this.modifier, this.listener,
      this.isNoArgsListener);
}

EventModifier? parseEventModifier(String s) {
  switch (s.toLowerCase()) {
    case 'preventDefault':
      return EventModifier.preventDefault;
    case 'stopPropagation':
      return EventModifier.stopPropagation;
    case 'passive':
      return EventModifier.passive;
    case 'nonpassive':
      return EventModifier.nonpassive;
    case 'capture':
      return EventModifier.capture;
    case 'once':
      return EventModifier.once;
    case 'self':
      return EventModifier.self;
    case 'trusted':
      return EventModifier.trusted;
  }
}

abstract class ElementBinder {
  final DartCodeVariable target;

  ElementBinder(this.target);
}

class BindThis extends ElementBinder {
  BindThis(DartCodeVariable target) : super(target);
}

class BindAttribute extends ElementBinder {
  final String attribute;

  BindAttribute(this.attribute, DartCodeVariable target) : super(target);
}
