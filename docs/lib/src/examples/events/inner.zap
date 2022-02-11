<script>
  void sayHello() {
    self.emitCustom('message', 'Hello!');
  }
</script>

<button on:click={sayHello}>
	Click to say hello
</button>
