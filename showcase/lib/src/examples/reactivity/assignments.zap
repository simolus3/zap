<script>
  var count = 0;

  void handleClick() => count++;
</script>

<button on:click={handleClick}>
  Clicked {count} {count == 1 ? 'time' : 'times'}
</button>
