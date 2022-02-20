<script>
  import 'package:riverpod_zap/riverpod.dart';
  import 'simple.zap';

  @prop
  int overriddenValue = 0;
</script>

<riverpod-scope overrides={[myProvider.overrideWithValue(overriddenValue)]}>
  <simple />
</riverpod-scope>