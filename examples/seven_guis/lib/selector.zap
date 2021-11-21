<script>
  import 'counter.zap';

  int selectedExample = 0;

  void showExample(int i) => selectedExample = i;
</script>

<style>
  div {
    style: block;
  }
</style>

<div>
  <button on:click="{() => showExample(0)}">Show counter example</button>
  <button on:click="{() => showExample(1)}">Show temperature converter</button>
  <button on:click="{() => showExample(2)}">Show counter example</button>
  <button on:click="{() => showExample(3)}">Show counter example</button>
  <button on:click="{() => showExample(4)}">Show counter example</button>
  <button on:click="{() => showExample(5)}">Show counter example</button>
  <button on:click="{() => showExample(6)}">Show counter example</button>
</div>

{#if selectedExample == 0}
  <counter />
{/if}