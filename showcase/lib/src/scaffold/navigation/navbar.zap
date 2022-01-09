<script>
  import '../examples.dart';
</script>

<style>
  nav {
    background-color: gray;
    grid-column: 1;
  }

  a {
    display: block;
  }
</style>

<nav>
  {#for group in groups}
    <h4>{group.title}</h4>

    {#for entry in group.children}
      <a href="#{entry.id}" on:click={() => selectedComponent.value = entry}>{entry.title}</a>
    {/for}
  {/for}
</nav>
