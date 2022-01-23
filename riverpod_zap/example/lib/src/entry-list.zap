<script>
  import 'package:riverpod_zap/riverpod.dart';

  import 'providers.dart';
  import 'todo.dart';
  import 'entry.zap';

  var shownEntries = watch(self.use(filteredTodos));
</script>

{#for entry, i in shownEntries}
  <entry entry={entry} />

  {#if i != shownEntries.length - 1}
    <hr>
  {/if}
{/for}
