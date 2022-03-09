import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:riverpod/riverpod.dart';

final Provider<MapboxModule> module =
    Provider((ref) => throw StateError('module must be provided.'));

final Provider<MapBoxMap> map =
    Provider((ref) => throw StateError('Map must be provided.'));

@JS('require')
external void _require(List<String> modules, Function(Object) callback);

@JS('mapboxgl')
external MapboxModule get _mapboxgl;

@JS()
@anonymous
abstract class MapboxModule {
  external String accessToken;

  Function get Map;
  Function get Popup;
  Function get Marker;
}

extension Constructors on MapboxModule {
  MapBoxMap newMap(MapOptions options) {
    return callConstructor(this.Map, [options]);
  }

  Popup newPopup(PopupOptions options) {
    return callConstructor(this.Popup, [options]);
  }

  Marker newMarker() => callConstructor(this.Marker, null);
}

@JS()
@anonymous
class MapBoxMap {
  external MapBoxMap(MapOptions initializer);

  external void remove();
}

@JS()
@anonymous
class MapOptions {
  external factory MapOptions({
    dynamic container,
    String? style,
    List<num>? center,
    num? zoom,
  });
}

@JS()
@anonymous
class Popup {
  external Popup(PopupOptions options);
  external void setText(String label);
}

@JS()
@anonymous
class PopupOptions {
  external factory PopupOptions({int offset});
}

@JS()
@anonymous
class Marker {
  external void setLngLat(List<num> position);
  external void setPopup(Popup popup);
  external void addTo(MapBoxMap map);
}

Future<MapboxModule>? _module;

Future<MapboxModule> load() {
  return _module ??= Future.sync(() async {
    final css = LinkElement()
      ..rel = 'stylesheet'
      ..href = 'https://api.mapbox.com/mapbox-gl-js/v2.7.0/mapbox-gl.css';

    document.head!.children.add(css);
    await css.onLoad.first;

    MapboxModule module;

    if (context.hasProperty('require')) {
      // require.js is available, load the module through that.
      final completer = Completer<MapboxModule>();
      _require(['https://api.mapbox.com/mapbox-gl-js/v2.7.0/mapbox-gl.js'],
          allowInterop((module) => completer.complete(module as MapboxModule)));
      module = await completer.future;
    } else {
      final script = ScriptElement()
        ..src = 'https://api.mapbox.com/mapbox-gl-js/v2.7.0/mapbox-gl.js';
      document.head!.children.add(script);
      await script.onLoad.first;

      // Load it from the globals then.
      module = _mapboxgl;
    }

    return module
      ..accessToken = const String.fromEnvironment('MAPBOX_TOKEN',
          defaultValue: 'token not set');
  });
}
