<script>
  import 'package:riverpod_zap/riverpod.dart';
  import 'package:riverpod_zap/riverpod-scope.zap';

  import 'entry-list.zap';
  import 'toolbar.zap';
</script>

<h1>todos</h1>

<riverpod-scope>
  <article>
    <header><toolbar /></header>
    <entry-list />
  </article>
</riverpod-scope>
