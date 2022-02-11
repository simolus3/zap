<script>
  import 'dart:math';

  final random = Random();

  Future<int> randomNumber() async {
    // Simulate loading a slow resource...
    await Future.delayed(const Duration(seconds: 2));
    return random.nextInt(100);
  }

  Future<int> number = randomNumber();
</script>

<button on:click={() => number = randomNumber()}>
  generate random number
</button>

{#await choosen from number}
  {#if choosen.hasData}
    The number is {choosen.data}
  {:else}
    Loading...
  {/if}
{/await}
