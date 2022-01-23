<script>
  import 'package:riverpod_zap/riverpod.dart';
  import 'providers.dart';
  import 'todo.dart';

  @prop
  Todo entry;

  void toggle() {
    self.read(todoListProvider.notifier).toggle(entry.id);
  }
</script>

<label for="entry-{entry.id}">
  <input type="checkbox" id="entry-{entry.id}" checked={entry.completed} on:change={toggle}>
  {entry.description}
</label>
