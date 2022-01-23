import 'dart:async';
import 'dart:html';

extension ZapText on Text {
  set zapText(String value) {
    if (wholeText != value) data = value;
  }
}

extension ZapElement on Element {
  /// Adds an empty attribute [key] if [value] is true, removes it otherwise.
  void applyBooleanAttribute(String key, bool value) {
    if (value) {
      attributes[key] = '';
    } else {
      attributes.remove(key);
    }
  }

  /// Sets the attribute [key] to the stringified [value] if it's not null,
  /// removes the attribute otherwise.
  void applyAttributeIfNotNull(String key, Object? value) {
    if (value == null) {
      attributes.remove(key);
    } else {
      attributes[key] = value.toString();
    }
  }

  void addComponentClass(String className) {
    classes.add(className);
  }

  void setClassAttribute(String scopedCssClass, String otherClasses) {
    attributes['class'] = '$scopedCssClass $otherClasses';
  }
}

extension ZapDomEvents<T extends Event> on Stream<T> {
  /// Applies modifiers to an event stream:
  ///
  /// - When [preventDefault] is enabled, [Event.preventDefault] is called
  ///   before passing it to listeners.
  /// - When [stopPropagation] is enabled, [Event.stopPropagation] is called
  ///   before passing it to listeners.
  /// - When [once] is enabled, the stream will close after the first event.
  /// - When [onlySelf] is set to a non-null element, the stream will only emit
  ///   events with a [Event.target] set to [onlySelf].
  /// - When [onlyTrusted] is enabled, the stream will only emit events for
  ///   which [Event.isTrusted] is `true`.
  Stream<T> withModifiers({
    bool preventDefault = false,
    bool stopPropagation = false,
    bool passive = false,
    bool once = false,
    Element? onlySelf,
    bool onlyTrusted = false,
  }) {
    return Stream<T>.eventTransformed(
      this,
      (sink) => _ModifierSink(
        sink,
        preventDefault,
        stopPropagation,
        passive,
        once,
        onlySelf,
        onlyTrusted,
      ),
    );
  }
}

class _ModifierSink<T extends Event> extends EventSink<T> {
  final EventSink<T> _downstream;

  final bool preventDefault;
  final bool stopPropagation;
  final bool passive;
  final bool once;
  final Element? onlySelf;
  final bool onlyTrusted;

  _ModifierSink(
    this._downstream,
    this.preventDefault,
    this.stopPropagation,
    this.passive,
    this.once,
    this.onlySelf,
    this.onlyTrusted,
  );

  @override
  void add(T event) {
    if (onlyTrusted && event.isTrusted != true) return;
    if (onlySelf != null && event.target != onlySelf) return;

    if (preventDefault) {
      event.preventDefault();
    }
    if (stopPropagation) {
      event.stopPropagation();
    }

    _downstream.add(event);

    if (once) close();
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _downstream.addError(error, stackTrace);
  }

  @override
  void close() {
    _downstream.close();
  }
}

T newElement<T extends HtmlElement>(String tagName) {
  return Element.tag(tagName) as T;
}
