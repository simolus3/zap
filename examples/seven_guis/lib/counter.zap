<script>
  var count = 0;
</script>

<input type="text" value={count} readonly=true />
<button on:click="{() => count++}">Count</button>
