<script>
  import 'package:riverpod_zap/riverpod.dart';
  import 'package:riverpod/riverpod.dart';
</script>

<script context="library">
  final myProvider = Provider((ref) => 0, name: 'simple');
</script>

The current value is {watch(self.use(myProvider))}.
