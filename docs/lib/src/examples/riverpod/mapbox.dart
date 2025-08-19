import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:riverpod/riverpod.dart';
import 'package:web/web.dart';

final Provider<MapboxModule> module = Provider(
  (ref) => throw StateError('module must be provided.'),
);

final Provider<MapBoxMap> map = Provider(
  (ref) => throw StateError('Map must be provided.'),
);

@JS('require')
external void _require(JSArray<JSString> modules, JSFunction callback);

@JS('mapboxgl')
external MapboxModule get _mapboxgl;

@JS()
extension type MapboxModule._(JSObject _) implements JSObject {
  external JSString accessToken;

  @JS('Map')
  external JSFunction get _map;

  @JS('Popup')
  external JSFunction get _popup;

  @JS('Marker')
  external JSFunction get _marker;

  MapBoxMap newMap(MapOptions options) {
    return _map.callAsConstructor<MapBoxMap>(options);
  }

  Popup newPopup(PopupOptions options) {
    return _popup.callAsConstructor(options);
  }

  Marker newMarker() {
    return _marker.callAsConstructor();
  }
}

@JS()
extension type MapBoxMap._(JSObject _) implements JSObject {
  external MapBoxMap(MapOptions initializer);

  external void remove();
}

@JS()
@anonymous
extension type MapOptions._(JSObject _) implements JSObject {
  external factory MapOptions({
    JSAny? container,
    JSString? style,
    JSArray<JSNumber>? center,
    JSNumber? zoom,
  });
}

@JS()
extension type Popup._(JSObject _) implements JSObject {
  external Popup(PopupOptions options);

  external void setText(String label);
}

@JS()
@anonymous
extension type PopupOptions._(JSObject _) implements JSObject {
  external factory PopupOptions({int offset});
}

@JS()
extension type Marker._(JSObject _) implements JSObject {
  external void setLngLat(JSArray<JSNumber> position);

  external void setPopup(Popup popup);

  external void addTo(MapBoxMap map);
}

Future<MapboxModule>? _module;

Future<MapboxModule> load() {
  return _module ??= Future.sync(() async {
    final css = HTMLLinkElement()
      ..rel = 'stylesheet'
      ..href = 'https://api.mapbox.com/mapbox-gl-js/v2.7.0/mapbox-gl.css';

    document.head!.appendChild(css);
    await css.onLoad.first;

    MapboxModule module;

    if (globalContext.has('require')) {
      // require.js is available, load the module through that.
      final completer = Completer<MapboxModule>();
      final jsModules = JSArray<JSString>.withLength(1)
        ..[0] = 'https://api.mapbox.com/mapbox-gl-js/v2.7.0/mapbox-gl.js'.toJS;
      _require(
        jsModules,
        (completer.complete as void Function(MapboxModule)).toJS,
      );
      module = await completer.future;
    } else {
      final script = HTMLScriptElement()
        ..src = 'https://api.mapbox.com/mapbox-gl-js/v2.7.0/mapbox-gl.js';
      document.head!.appendChild(script);
      await script.onLoad.first;

      // Load it from the globals then.
      module = _mapboxgl;
    }

    return module
      ..accessToken = const String.fromEnvironment(
        'MAPBOX_TOKEN',
        defaultValue: 'token not set',
      ).toJS;
  });
}
