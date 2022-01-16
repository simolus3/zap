<script>
  num x = 0.0;
  num y = 0.0;
</script>

<style>
  div {
    width: 100%;
    height: 100%;
  }
</style>

<div on:mousemove={(MouseEvent e) { x = e.client.x; y = e.client.y; }}>
	The mouse position is {x} x {y}
</div>
