<script>
  @Property()
  var counter = 0;

  void increase() => counter++;
</script>

<button on:click={increase}>
  Clicked {counter} {counter == 1 ? 'time' : 'times' }
</button>
