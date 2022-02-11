<script>
  num x = 0.0;
  num y = 0.0;

  void handleMouseMove(MouseEvent event) {
    x = event.client.x;
    y = event.client.y;
  }
</script>

<style>
  div {
    width: 100%;
    height: 100%;
  }
</style>


<div on:mousemove={handleMouseMove}>
	The mouse position is {x} x {y}
</div>
