<script>
  import 'dart:js_interop';

  import 'mapbox.dart' as mapbox;
  import 'package:riverpod_zap/riverpod.dart';

  @prop
  num lat;
  @prop
  num lon;
  @prop
  String label;

  final map = watch(self.use(mapbox.map));

  final module = self.read(mapbox.module);
  final popup = module.newPopup(mapbox.PopupOptions(offset: 25))
      ..setText(label);
  module.newMarker()
      ..setLngLat([lon.toJS, lat.toJS].toJS)
      ..setPopup(popup)
      ..addTo(map);
</script>
