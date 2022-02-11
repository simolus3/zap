<script>
  // Updates to this variable are reflected in the component
  // right away!
  var counter = 0;

  void handleClick() => counter++;
</script>

<button on:click={handleClick}>
  You've clicked this button { counter }
  { counter == 1 ? 'time' : 'times' }
</button>
