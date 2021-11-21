<script>
  String celsiusString = '';
  String fahrenheitString = '';

  // Update fahrenheit when celsius updates
  $: celsiusString = ((double.parse(fahrenheitString) - 32) * (5 / 9)).toString();
  // ...and vice-versa
  $: fahrenheitString = (double.parse(celsiusString) * 9/5 + 32).toString();
</script>

<input type="number" />
