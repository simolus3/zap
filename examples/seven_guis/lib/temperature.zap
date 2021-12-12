<script>
  num celsius = 5;
  num fahrenheit = 41;

  late InputElement inputCelsius;
  late InputElement inputFahrenheit;

  void updateInCelsius() {
    celsius = num.parse(inputCelsius.value!);
    fahrenheit = celsius * 9 / 5 + 32;
  }

  void updateInFahrenheit() {
    fahrenheit = num.parse(inputFahrenheit.value!);
    celsius = (fahrenheit - 32) * 5 / 9;
  }
</script>

<input type="number" bind:this={inputCelsius} value={celsius} on:input={updateInCelsius} /> °C =
<input type="number" bind:this={inputFahrenheit} value={fahrenheit} on:input={updateInFahrenheit} /> °F
