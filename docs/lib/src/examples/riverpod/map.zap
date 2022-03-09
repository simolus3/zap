<script>
  import 'dart:html';
  import 'package:riverpod_zap/riverpod.dart';
  import 'mapbox.dart' as mapbox;

  @prop
  num lat;
  @prop
  num lon;
  @prop
  num zoom;

  late Element container;
  mapbox.MapBoxMap? map;
  mapbox.MapboxModule? module;

  self.onMount(() async {
    final loaded = await mapbox.load();
    module = loaded;
    map = loaded.newMap(mapbox.MapOptions(
      container: container,
      style: 'mapbox://styles/mapbox/streets-v9',
      center: [lon, lat],
      zoom: zoom,
    ));
  });

  self.onDestroy(() {
    map?.remove();
  });
</script>
<style>
  div {
    width: 100%;
    height: 100%;
  }
</style>


<div bind:this="{container}">
  {#if map != null}
    <riverpod-scope overrides={[mapbox.map.overrideWithValue(map!), mapbox.module.overrideWithValue(module!)]}>
      <slot />
    </riverpod-scope>
  {/if}
</div>
