<script>
  var count = 0;

  $: if (count >= 10) {
    window.alert('Count is dangerously high!');
    count = 9;
  }

  void handleClick() => count++;
</script>

<button on:click={handleClick}>
  Clicked {count} { count == 1 ? 'time' : 'times' }
</button>
