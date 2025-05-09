import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

const knownTags = {
  // Note: Skipping base, body, content, head, html, link, meta, script, shadow,
  // slot, style, template, title,
  'a': KnownElementInfo('HTMLAnchorElement'),
  'area': KnownElementInfo('HTMLAreaElement'),
  'br': KnownElementInfo('HTMLBRElement'),
  'button': KnownElementInfo('HTMLButtonElement'),
  'canvas': KnownElementInfo('HTMLCanvasElement'),
  'data': KnownElementInfo('HTMLDataElement'),
  'datalist': KnownElementInfo('HTMLDataListElement'),
  'details': KnownElementInfo('HTMLDetailsElement'),
  'dialog': KnownElementInfo('HTMLDialogElement'),
  'div': KnownElementInfo('HTMLDivElement'),
  'dl': KnownElementInfo('HTMLDListElement'),
  'embed': KnownElementInfo('HTMLEmbedElement'),
  'fieldset': KnownElementInfo('HTMLFieldSetElement'),
  'form': KnownElementInfo('HTMLFormElement'),
  'h1': KnownElementInfo('HTMLHeadingElement', constructorName: 'h1'),
  'h2': KnownElementInfo('HTMLHeadingElement', constructorName: 'h2'),
  'h3': KnownElementInfo('HTMLHeadingElement', constructorName: 'h3'),
  'h4': KnownElementInfo('HTMLHeadingElement', constructorName: 'h4'),
  'h5': KnownElementInfo('HTMLHeadingElement', constructorName: 'h5'),
  'h6': KnownElementInfo('HTMLHeadingElement', constructorName: 'h6'),
  'hr': KnownElementInfo('HTMLHRElement'),
  'iframe': KnownElementInfo('HTMLIFrameElement'),
  'image': KnownElementInfo('HTMLImageElement'),
  'input': KnownElementInfo(
      'HTMLInputElement'), // todo: Special case the different kinds?
  'li': KnownElementInfo('HTMLLIElement'),
  'label': KnownElementInfo('HTMLLabelElement'),
  'legend': KnownElementInfo('HTMLLegendElement'),
  'map': KnownElementInfo('HTMLMapElement'),
  'media': KnownElementInfo('HTMLMediaElement'),
  'menu': KnownElementInfo('HTMLMenuElement'),
  'meter': KnownElementInfo('HTMLMeterElement'),
  'del': KnownElementInfo('HTMLModElement', instantiable: false),
  'ins': KnownElementInfo('HTMLModElement', instantiable: false),
  'ol': KnownElementInfo('HTMLOListElement'),
  'object': KnownElementInfo('HTMLObjectElement'),
  'optgroup': KnownElementInfo('HTMLOptGroupElement'),
  'option': KnownElementInfo('HTMLOptionElement'),
  'output': KnownElementInfo('HTMLOutputElement'),
  'p': KnownElementInfo('HTMLParagraphElement'),
  'param': KnownElementInfo('HTMLParamElement'),
  'picture': KnownElementInfo('HTMLPictureElement', instantiable: false),
  'pre': KnownElementInfo('HTMLPreElement'),
  'progress': KnownElementInfo('HTMLProgressElement'),
  'q': KnownElementInfo('HTMLQuoteElement'),
  'select': KnownElementInfo('HTMLSelectElement'),
  'source': KnownElementInfo('HTMLSourceElement'),
  'span': KnownElementInfo('HTMLSpanElement'),
  'caption': KnownElementInfo('HTMLTableCaptionElement'),
  'td': KnownElementInfo('HTMLTableCellElement'),
  'col': KnownElementInfo('HTMLTableColElement'),
  'table': KnownElementInfo('HTMLTableElement'),
  'tr': KnownElementInfo('HTMLTableRowElement'),
  'textarea': KnownElementInfo('HTMLTextAreaElement'),
  'time': KnownElementInfo('HTMLTimeElement'),
  'track': KnownElementInfo('HTMLTrackElement'),
  'ul': KnownElementInfo('HTMLUListElement'),
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
  final LibraryElement packageWeb;

  final Map<String, InterfaceType> _types = {};
  final Map<String, DomEventType> knownEvents = {};

  late final InterfaceType event = _nonNullableWithoutTypeParameters('Event');
  late final InterfaceType customEvent =
      _nonNullableWithoutTypeParameters('CustomEvent');
  late final InterfaceType element =
      _nonNullableWithoutTypeParameters('Element');

  ResolvedDomTypes(this.packageWeb) {
    _readKnownInformation();
  }

  /// Extracts known elements and events from the resolved `package:web`
  /// library.
  void _readKnownInformation() {
    final elementEventGetters =
        packageWeb.exportNamespace.get('EventStreamProviders') as ClassElement;
    for (final field in elementEventGetters.fields) {
      final value = field.computeConstantValue();
      if (value == null) continue;

      final type = value.type;
      if (type is! InterfaceType) {
        continue;
      }

      final name = value.getField('_eventType')!.toStringValue()!;

      knownEvents[name] = DomEventType(
        '${element.name}.${field.name}',
        type.typeArguments.single as InterfaceType? ??
            event.element.instantiate(
                typeArguments: const [],
                nullabilitySuffix: NullabilitySuffix.none),
      );
    }
  }

  InterfaceElement _class(String name) {
    return packageWeb.exportNamespace.get(name) as InterfaceElement;
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
