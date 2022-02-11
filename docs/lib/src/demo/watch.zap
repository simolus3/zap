<script>
  import 'dart:async';

  import 'package:zap/zap.dart';

  final now = watch(currentTime);
</script>
<script context="module">
  final currentTime = Watchable.stream(
    Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
    DateTime.now()
  );
</script>

The current time is {now}.
