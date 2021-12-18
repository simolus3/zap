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
      attributes.remove(key);
    } else {
      attributes[key] = '';
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
}

extension ZapDomEvents<T extends Event> on ElementStream<T> {
  /// Applies modifiers to an event stream:
  ///
  /// - When [capture] is enabled, the stream emits events from the capturing
  ///   phase instead of the bubbling phase
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
    bool capture = false,
    bool preventDefault = false,
    bool stopPropagation = false,
    bool passive = false,
    bool once = false,
    Element? onlySelf,
    bool onlyTrusted = false,
  }) {
    final stream = capture ? _CapturingStream(this) : this;

    return Stream<T>.eventTransformed(
      stream,
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

class _CapturingStream<T extends Event> extends Stream<T> {
  final ElementStream<T> stream;

  _CapturingStream(this.stream);

  @override
  bool get isBroadcast => stream.isBroadcast;

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return stream.capture(onData ?? (_) {})
      ..onError(onError)
      ..onDone(onDone);
  }
}

T newElement<T extends HtmlElement>(String tagName) {
  return Element.tag(tagName) as T;
}
