<script>
  void handleClick() {
    window.alert('no more alerts');
  }
</script>

<button on:click|once={handleClick}>
  Click me
</button>

