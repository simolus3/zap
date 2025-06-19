import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

// Note: Skipping base, body, head, html, link, meta, script, slot, style,
// template, title,
const knownTags = {
  'a': 'HTMLAnchorElement',
  'abbr': 'HTMLElement',
  'acronym': 'HTMLElement', // Deprecated
  'address': 'HTMLElement',
  'applet': 'HTMLAppletElement', // Deprecated
  'area': 'HTMLAreaElement',
  'article': 'HTMLElement',
  'aside': 'HTMLElement',
  'audio': 'HTMLAudioElement',
  'b': 'HTMLElement',
  // 'base': 'HTMLBaseElement',
  'basefont': 'HTMLElement', // Deprecated
  'bdi': 'HTMLElement',
  'bdo': 'HTMLElement',
  'blockquote': 'HTMLQuoteElement',
  // 'body': 'HTMLBodyElement',
  'br': 'HTMLBRElement',
  'button': 'HTMLButtonElement',
  'canvas': 'HTMLCanvasElement',
  'caption': 'HTMLTableCaptionElement',
  'center': 'HTMLElement', // Deprecated
  'cite': 'HTMLElement',
  'code': 'HTMLElement',
  'col': 'HTMLTableColElement',
  'colgroup': 'HTMLTableColElement',
  'data': 'HTMLDataElement',
  'datalist': 'HTMLDataListElement',
  'dd': 'HTMLElement',
  'del': 'HTMLModElement',
  'details': 'HTMLDetailsElement',
  'dfn': 'HTMLElement',
  'dialog': 'HTMLDialogElement',
  'dir': 'HTMLDirectoryElement', // Deprecated
  'div': 'HTMLDivElement',
  'dl': 'HTMLDListElement',
  'dt': 'HTMLElement',
  'em': 'HTMLElement',
  'embed': 'HTMLEmbedElement',
  'fieldset': 'HTMLFieldSetElement',
  'figcaption': 'HTMLElement',
  'figure': 'HTMLElement',
  'font': 'HTMLFontElement', // Deprecated
  'footer': 'HTMLElement',
  'form': 'HTMLFormElement',
  'frame': 'HTMLFrameElement', // Deprecated
  'frameset': 'HTMLFrameSetElement', // Deprecated
  'h1': 'HTMLHeadingElement',
  'h2': 'HTMLHeadingElement',
  'h3': 'HTMLHeadingElement',
  'h4': 'HTMLHeadingElement',
  'h5': 'HTMLHeadingElement',
  'h6': 'HTMLHeadingElement',
  // 'head': 'HTMLHeadElement',
  'header': 'HTMLElement',
  'hr': 'HTMLHRElement',
  // 'html': 'HTMLHtmlElement',
  'i': 'HTMLElement',
  'iframe': 'HTMLIFrameElement',
  'img': 'HTMLImageElement',
  'input': 'HTMLInputElement', // todo: Special case the different kinds?
  'ins': 'HTMLModElement',
  'kbd': 'HTMLElement',
  'label': 'HTMLLabelElement',
  'legend': 'HTMLLegendElement',
  'li': 'HTMLLIElement',
  // 'link': 'HTMLLinkElement',
  'main': 'HTMLElement',
  'map': 'HTMLMapElement',
  'mark': 'HTMLElement',
  'marquee': 'HTMLMarqueeElement', // Deprecated
  'menu': 'HTMLMenuElement',
  // 'meta': 'HTMLMetaElement',
  'meter': 'HTMLMeterElement',
  'nav': 'HTMLElement',
  'noframes': 'HTMLElement', // Deprecated
  'noscript': 'HTMLElement',
  'object': 'HTMLObjectElement',
  'ol': 'HTMLOListElement',
  'optgroup': 'HTMLOptGroupElement',
  'option': 'HTMLOptionElement',
  'output': 'HTMLOutputElement',
  'p': 'HTMLParagraphElement',
  'param': 'HTMLParamElement',
  'picture': 'HTMLPictureElement',
  'pre': 'HTMLPreElement',
  'progress': 'HTMLProgressElement',
  'q': 'HTMLQuoteElement',
  'rp': 'HTMLElement',
  'rt': 'HTMLElement',
  'ruby': 'HTMLElement',
  's': 'HTMLElement',
  'samp': 'HTMLElement',
  // 'script': 'HTMLScriptElement',
  'section': 'HTMLElement',
  'select': 'HTMLSelectElement',
  'slot': 'HTMLSlotElement',
  'small': 'HTMLElement',
  'source': 'HTMLSourceElement',
  'span': 'HTMLSpanElement',
  'strike': 'HTMLElement', // Deprecated
  'strong': 'HTMLElement',
  // 'style': 'HTMLStyleElement',
  'sub': 'HTMLElement',
  'summary': 'HTMLElement',
  'sup': 'HTMLElement',
  'table': 'HTMLTableElement',
  'tbody': 'HTMLTableSectionElement',
  'td': 'HTMLTableCellElement',
  // 'template': 'HTMLTemplateElement',
  'textarea': 'HTMLTextAreaElement',
  'tfoot': 'HTMLTableSectionElement',
  'th': 'HTMLTableCellElement',
  'thead': 'HTMLTableSectionElement',
  'time': 'HTMLTimeElement',
  // 'title': 'HTMLTitleElement',
  'tr': 'HTMLTableRowElement',
  'track': 'HTMLTrackElement',
  'tt': 'HTMLElement', // Deprecated
  'u': 'HTMLElement',
  'ul': 'HTMLUListElement',
  'var': 'HTMLElement',
  'video': 'HTMLVideoElement',
  'wbr': 'HTMLElement',
};

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
  late final InterfaceType customEvent = _nonNullableWithoutTypeParameters(
    'CustomEvent',
  );
  late final InterfaceType element = _nonNullableWithoutTypeParameters(
    'Element',
  );

  ResolvedDomTypes(this.packageWeb) {
    _readKnownInformation();
  }

  /// Extracts known elements and events from the resolved
  /// `package:web/web.dart` library.
  void _readKnownInformation() {
    final eventStreamProviders = _class('EventStreamProviders');

    for (final field in eventStreamProviders.fields) {
      final value = field.computeConstantValue();
      if (value == null) continue;

      final name = value.getField('_eventType')!.toStringValue()!;
      knownEvents[name] = DomEventType(
        'EventStreamProviders.${field.name}',
        (field.type as InterfaceType).typeArguments.single as InterfaceType? ??
            event.element.instantiate(
              typeArguments: const [],
              nullabilitySuffix: NullabilitySuffix.none,
            ),
      );
    }
  }

  ClassElement _class(String name) {
    return packageWeb.exportNamespace.get(name) as ClassElement;
  }

  ExtensionTypeElement _extension(String name) {
    return packageWeb.exportNamespace.get(name) as ExtensionTypeElement;
  }

  InterfaceType _nonNullableWithoutTypeParameters(String name) {
    return _types.putIfAbsent(name, () {
      return _extension(name).instantiate(
        typeArguments: const [],
        nullabilitySuffix: NullabilitySuffix.none,
      );
    });
  }

  InterfaceType? dartTypeForElement(String tagName) {
    final known = knownTags[tagName.toLowerCase()];

    if (known != null) {
      return _nonNullableWithoutTypeParameters(known);
    }
  }
}
