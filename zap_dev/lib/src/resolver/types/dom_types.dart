import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

const knownTags = {
  // Note: Skipping base, body, content, head, html, link, meta, script, shadow,
  // slot, style, template, title,
  'a': KnownElementInfo('AnchorElement'),
  'area': KnownElementInfo('AreaElement'),
  'br': KnownElementInfo('BRElement'),
  'button': KnownElementInfo('ButtonElement'),
  'canvas': KnownElementInfo('CanvasElement'),
  'data': KnownElementInfo('DataElement'),
  'datalist': KnownElementInfo('DataListElement'),
  'details': KnownElementInfo('DetailsElement'),
  'dialog': KnownElementInfo('DialogElement'),
  'div': KnownElementInfo('DivElement'),
  'dl': KnownElementInfo('DListElement'),
  'embed': KnownElementInfo('EmbedElement'),
  'fieldset': KnownElementInfo('FieldSetElement'),
  'form': KnownElementInfo('FormElement'),
  'h1': KnownElementInfo('HeadingElement', constructorName: 'h1'),
  'h2': KnownElementInfo('HeadingElement', constructorName: 'h2'),
  'h3': KnownElementInfo('HeadingElement', constructorName: 'h3'),
  'h4': KnownElementInfo('HeadingElement', constructorName: 'h4'),
  'h5': KnownElementInfo('HeadingElement', constructorName: 'h5'),
  'h6': KnownElementInfo('HeadingElement', constructorName: 'h6'),
  'hr': KnownElementInfo('HRElement'),
  'iframe': KnownElementInfo('IFrameElement'),
  'image': KnownElementInfo('ImageElement'),
  'input': KnownElementInfo(
      'InputElement'), // todo: Special case the different kinds?
  'li': KnownElementInfo('LIElement'),
  'label': KnownElementInfo('LabelElement'),
  'legend': KnownElementInfo('LegendElement'),
  'map': KnownElementInfo('MapElement'),
  'media': KnownElementInfo('MediaElement'),
  'menu': KnownElementInfo('MenuElement'),
  'meter': KnownElementInfo('MeterElement'),
  'del': KnownElementInfo('ModElement', instantiable: false),
  'ins': KnownElementInfo('ModElement', instantiable: false),
  'ol': KnownElementInfo('OListElement'),
  'object': KnownElementInfo('Object'),
  'optgroup': KnownElementInfo('OptGroupElement'),
  'option': KnownElementInfo('OptionElement'),
  'output': KnownElementInfo('OutputElement'),
  'p': KnownElementInfo('ParagraphElement'),
  'param': KnownElementInfo('ParamElement'),
  'picture': KnownElementInfo('PictureElement', instantiable: false),
  'pre': KnownElementInfo('PreElement'),
  'progress': KnownElementInfo('ProgressElement'),
  'q': KnownElementInfo('QuoteElement'),
  'select': KnownElementInfo('SelectElement'),
  'source': KnownElementInfo('SourceElement'),
  'span': KnownElementInfo('SpanElement'),
  'caption': KnownElementInfo('TableCaptionElement'),
  'td': KnownElementInfo('TableCellElement'),
  'col': KnownElementInfo('TableColElement'),
  'table': KnownElementInfo('TableElement'),
  'tr': KnownElementInfo('TableRowElement'),
  'textarea': KnownElementInfo('TextAreaElement'),
  'time': KnownElementInfo('TimeElement', instantiable: false),
  'track': KnownElementInfo('TrackElement'),
  'ul': KnownElementInfo('UListElement'),
};

class KnownElementInfo {
  final String className;
  final String constructorName;

  /// Whether this element has a Dart constructor, or whether we need to
  /// construct instances through `Element.tag`
  final bool instantiable;

  const KnownElementInfo(this.className,
      {this.constructorName = '', this.instantiable = true});
}

class DomEventType {
  final String providerExpression;
  final InterfaceType eventType;

  DomEventType(this.providerExpression, this.eventType);
}

class ResolvedDomTypes {
  final LibraryElement dartHtml;

  final Map<String, InterfaceType> _types = {};
  final Map<String, DomEventType> knownEvents = {};

  late final InterfaceType event = _nonNullableWithoutTypeParameters('Event');
  late final InterfaceType customEvent =
      _nonNullableWithoutTypeParameters('CustomEvent');
  late final InterfaceType element =
      _nonNullableWithoutTypeParameters('Element');

  ResolvedDomTypes(this.dartHtml) {
    _readKnownInformation();
  }

  /// Extracts known elements and events from the resolved `dart:html` library.
  void _readKnownInformation() {
    final typeSystem = dartHtml.typeSystem;
    final baseEventProvider = typeSystem.instantiateInterfaceToBounds(
      element: _class('EventStreamProvider'),
      nullabilitySuffix: NullabilitySuffix.none,
    );

    void addEventsFromClass(ClassElement element) {
      for (final field in element.fields) {
        final value = field.computeConstantValue();
        if (value == null) continue;

        final type = value.type;
        if (type is! InterfaceType ||
            !typeSystem.isAssignableTo(type, baseEventProvider)) {
          continue;
        }

        final String name;
        // These two are using a dynamic name in the SDK and need to be special-
        // cased.
        if (field.name == 'mouseWheelEvent') {
          name = 'wheel';
        } else if (field.name == 'transitionEndEvent') {
          name = 'transitionend';
        } else {
          name = value.getField('_eventType')!.toStringValue()!;
        }

        knownEvents[name] = DomEventType(
          '${element.name}.${field.name}',
          type.typeArguments.single as InterfaceType? ??
              event.element.instantiate(
                  typeArguments: const [],
                  nullabilitySuffix: NullabilitySuffix.none),
        );
      }
    }

    for (final child in dartHtml.topLevelElements) {
      if (child.name == 'GlobalEventHandlers' || child.name == 'Element') {
        addEventsFromClass(child as ClassElement);
      }
    }
  }

  ClassElement _class(String name) {
    return dartHtml.getClass(name)!;
  }

  InterfaceType _nonNullableWithoutTypeParameters(String name) {
    return _types.putIfAbsent(name, () {
      return _class(name).instantiate(
          typeArguments: const [], nullabilitySuffix: NullabilitySuffix.none);
    });
  }

  InterfaceType? dartTypeForElement(String tagName) {
    final known = knownTags[tagName.toLowerCase()];

    if (known != null) {
      return _nonNullableWithoutTypeParameters(known.className);
    }
  }
}
