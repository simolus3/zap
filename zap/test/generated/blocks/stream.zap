<script>
  @prop
  late Stream<String> s;
</script>

{#await each snapshot from s}
{#if snapshot.hasData}
  data: {snapshot.data}
{:else if snapshot.hasError}
  error: {snapshot.error}
{:else}
  no data / no error
{/if}
{/await}
