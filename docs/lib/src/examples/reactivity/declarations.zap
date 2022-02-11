<script>
  var count = 1;
  int doubled, quadrupled;

  // The `$:` will re-run the statement if any of the variables used changes.
  $: doubled = count * 2;
  $: quadrupled = doubled * 2;

  void handleClick() => count++;
</script>

<button on:click={handleClick}>
  Count: {count}
</button>

<p>{count} * 2 = {doubled}</p>
<p>{doubled} * 2 = {quadrupled}</p>
