<script>
  import 'dart:async';

  final stream = StreamController<String>().stream;
</script>

{#await each snapshot from stream}
  Hello {snapshot}
{/await}

{#await snapshot from stream.first}
  Hello {snapshot}
{/await}

