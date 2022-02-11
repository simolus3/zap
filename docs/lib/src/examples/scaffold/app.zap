<script>
  import '../component.dart';
  import '../examples.dart';

  import 'navbar.zap';
  import 'sources.zap';

  var currentSelection = watch(selectedComponent);

  $: document.title = '${currentSelection.title} | Zap Example';

  self.onMount(() {
    final uri = Uri.base;
    if (uri.hasFragment) {
      // Restore selection from uri
      final component = componentFromId(uri.fragment);
      if (component != null) {
        selectedComponent.value = component;
      }
    }
  });
</script>

<style>
  div {
    display: grid;
    grid-template-columns: 1fr 2fr 1fr;
  }

  main {
    grid-column: 2;
  }

  aside {
    grid-column: 3;
  }
</style>

<div>
  <navbar />
  <main>
    <sources />
  </main>
  <aside>
    <zap:component this={instantiate(currentSelection)} />
  </aside>
</div>
