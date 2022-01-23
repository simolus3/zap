<script>
  import 'package:riverpod_zap/riverpod.dart';
  import 'providers.dart';

  var uncompleted = watch(self.use(uncompletedTodosCount));
  var filterMode = watch(self.use(todoListFilter));

  TextInputElement? text;

  void applyFilter(TodoListFilter filter) {
    self.read(todoListFilter.notifier).state = filter;
  }

  void addNew() {
    self.read(todoListProvider.notifier).add(text!.value!);
    text!.value = '';
  }
</script>

<style>
  div {
    float: right;
  }

  a {
    margin: 0px 2px;
  }

  label {
    margin-top: 20px;
  }
</style>

<strong>{uncompleted} {uncompleted == 1 ? 'item' : 'items'} left</strong>

<div>
<a class={filterMode == TodoListFilter.all ? '' : 'secondary'} on:click={() => applyFilter(TodoListFilter.all)}>All</a>
<a class={filterMode == TodoListFilter.active ? '' : 'secondary'} on:click={() => applyFilter(TodoListFilter.active)}>Active</a>
<a class={filterMode == TodoListFilter.completed ? '' : 'secondary'} on:click={() => applyFilter(TodoListFilter.completed)}>Completed</a>
</div>

<label for="add-new">
What needs to be done?
<input bind:this={text} type="text" id="add-new" placeholder="What needs to be done?" on:change={addNew}>
</label>
