<script>
  Timer? runningTimer;
  Duration elapsed = Duration.zero;
  Duration target = const Duration(seconds: 5);

  late InputElement rangeSelector;

  void updateTarget() {
    
  }
</script>

<label>
  Elapsed time:
  <progress value="{elapsed.inMilliseconds / target.inMilliseconds}"> </progress>
</label>

<div>
  {(elapsed.inMilliseconds / 1000).toFixed(1)}s
</div>

<label>
	duration:
	<input type="range" bind:this={rangeSelector} value="{target.inMilliseconds}" on:input={updateTarget} min="1" max="20000">
</label>
