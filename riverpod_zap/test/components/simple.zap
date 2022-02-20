<script>
  import 'package:riverpod_zap/riverpod.dart';
  import 'package:riverpod/riverpod.dart';

  var value = watch(self.use(myProvider));
</script>

<script context="library">
  final myProvider = Provider((ref) => 0, name: 'simple');
</script>

The current value is {value}.
