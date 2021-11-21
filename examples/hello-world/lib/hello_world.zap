<script>
  import 'counting_button.zap';
  import 'if_block.zap';

  var name = 'world';

  void update() {
    name = 'zap';
  }
</script>
<style>
  h1 {
    color: blue;
  }
</style>

<h1 on:click|once={update}>Hello {name}!</h1>

<if_block />
<counting_button />
