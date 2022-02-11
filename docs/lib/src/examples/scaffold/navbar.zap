<script>
  import '../component.dart';
  import '../examples.dart';
</script>

<style>
  aside {
    grid-column: 1;
  }

  a {
    display: block;
    margin-left: 1em;
  }

  h4 {
    margin-bottom: 0;
  }
</style>

<aside>
  {#for group in examples}
    <h4>{group.title}</h4>

    {#for entry in group.children}
      <a href="#{entry.id}" on:click={() => selectedComponent.value = entry}>{entry.title}</a>
    {/for}
  {/for}
</aside>
