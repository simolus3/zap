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
  'details': KnownElementInfo('details'),
  'dialog': KnownElementInfo('dialog'),
  'div': KnownElementInfo('div'),
  'dl': KnownElementInfo('DListElement'),
  'embed': KnownElementInfo('embed'),
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
  'input': KnownElementInfo('input'), // todo: Special case the different kinds?
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

const knownEvents = {
  'abort': KnownEventType('onAbort'),
  'beforecopy': KnownEventType('onBeforeCopy'),
  'beforecut': KnownEventType('onBeforeCut'),
  'beforepaste': KnownEventType('onBeforePaste'),
  'blur': KnownEventType('onBlur'),
  'canplay': KnownEventType('onCanPlay'),
  'canplaythrough': KnownEventType('onCanPlayThrough'),
  'change': KnownEventType('onChange'),
  'click': KnownEventType('onClick', 'MouseEvent'),
  'contextmenu': KnownEventType('onContextMenu', 'MouseEvent'),
  'copy': KnownEventType('onCopy', 'ClipboardEvent'),
  'cut': KnownEventType('onCut', 'ClipboardEvent'),
  'doubleclick': KnownEventType('onDoubleClick'),
  'drag': KnownEventType('onDrag', 'MouseEvent'),
  'dragend': KnownEventType('onDragEnd', 'MouseEvent'),
  'dragenter': KnownEventType('onDragEnter', 'MouseEvent'),
  'drageeave': KnownEventType('onDragLeave', 'MouseEvent'),
  'dragover': KnownEventType('onDragOver', 'MouseEvent'),
  'dragstart': KnownEventType('onDragStart', 'MouseEvent'),
  'drop': KnownEventType('onDrop', 'MouseEvent'),
  'durationchange': KnownEventType('onDurationChange'),
  'emptied': KnownEventType('onEmptied'),
  'ended': KnownEventType('onEnded'),
  'error': KnownEventType('onError'),
  'focus': KnownEventType('onFocus'),
  'fullscreenchange': KnownEventType('onFullscreenChange'),
  'fullscreenerror': KnownEventType('onFullscreenError'),
  'input': KnownEventType('onInput'),
  'invalid': KnownEventType('onInvalid'),
  'keydown': KnownEventType('onKeyDown', 'KeyboardEvent'),
  'keypress': KnownEventType('onKeyPress', 'KeyboardEvent'),
  'keyup': KnownEventType('onKeyUp', 'KeyboardEvent'),
  'load': KnownEventType('onLoad'),
  'loadeddata': KnownEventType('onLoadedData'),
  'loadedmetadata': KnownEventType('onLoadedMetadata'),
  'mousedown': KnownEventType('onMouseDown', 'MouseEvent'),
  'mouseenter': KnownEventType('onMouseEnter', 'MouseEvent'),
  'mouseleave': KnownEventType('onMouseLeave', 'MouseEvent'),
  'mousemove': KnownEventType('onMouseMove', 'MouseEvent'),
  'mouseout': KnownEventType('onMouseOut', 'MouseEvent'),
  'mouseover': KnownEventType('onMouseOver', 'MouseEvent'),
  'mouseup': KnownEventType('onMouseUp', 'MouseEvent'),
  'mousewheel': KnownEventType('onMouseWheel', 'MouseEvent'),
  'paste': KnownEventType('onPaste', 'ClipboardEvent'),
  'pause': KnownEventType('onPause'),
  'play': KnownEventType('onPlay'),
  'playing': KnownEventType('onPlaying'),
  'ratechange': KnownEventType('onRateChange'),
  'reset': KnownEventType('onReset'),
  'resize': KnownEventType('onResize'),
  'scroll': KnownEventType('onScroll'),
  'search': KnownEventType('onSearch'),
  'seeked': KnownEventType('onSeeked'),
  'seeking': KnownEventType('onSeeking'),
  'select': KnownEventType('onSelect'),
  'selectstart': KnownEventType('onSelectStart'),
  'stalled': KnownEventType('onStalled'),
  'submit': KnownEventType('onSubmit'),
  'suspend': KnownEventType('onSuspend'),
  'timeupdate': KnownEventType('onTimeUpdate'),
  'touchcancel': KnownEventType('onTouchCancel', 'TouchEvent'),
  'touchenter': KnownEventType('onTouchEnter', 'TouchEvent'),
  'touchleave': KnownEventType('onTouchLeave', 'TouchEvent'),
  'touchmove': KnownEventType('onTouchMove', 'TouchEvent'),
  'touchstart': KnownEventType('onTouchStart', 'TouchEvent'),
  'transitionend': KnownEventType('onTransitionEnd', 'TransitionEvent'),
  'volumechange': KnownEventType('onVolumeChange'),
  'waiting': KnownEventType('onWaiting'),
  'wheel': KnownEventType('onWheel', 'WheelEvent'),
};

class KnownEventType {
  final String getterName;
  final String type;

  const KnownEventType(this.getterName, [this.type = 'Event']);
}

class ResolvedDomTypes {
  final LibraryElement dartHtml;

  final Map<String, InterfaceType> _types = {};

  ResolvedDomTypes(this.dartHtml);

  InterfaceType _nonNullableWithoutTypeParameters(String name) {
    return _types.putIfAbsent(name, () {
      return dartHtml.getType(name)!.instantiate(
          typeArguments: const [], nullabilitySuffix: NullabilitySuffix.none);
    });
  }

  /// The `Element` type from `dart.html`.
  InterfaceType get element {
    return _nonNullableWithoutTypeParameters('Element');
  }

  /// The `Event` type from `dart:html`.
  InterfaceType get event {
    return _nonNullableWithoutTypeParameters('Event');
  }

  InterfaceType? dartTypeForElement(String tagName) {
    final known = knownTags[tagName.toLowerCase()];

    if (known != null) {
      return _nonNullableWithoutTypeParameters(known.className);
    }
  }

  InterfaceType? dartTypeForEvent(String eventName) {
    final known = knownEvents[eventName.toLowerCase()];

    if (known != null) {
      return _nonNullableWithoutTypeParameters(known.type);
    }
  }
}
