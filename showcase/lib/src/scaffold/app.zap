<script>
  import 'navigation/navbar.zap';
  import 'examples.dart';

  var currentSelection = watch(selectedComponent);
</script>

<style>
  div {
    display: grid;
    grid-template-columns: 1fr 3fr;
  }

  main {
    grid-column: 2;
  }
</style>

<div>
  <navbar />
  <main>
    <zap:component this={currentSelection.create()} />
  </main>
</div>
