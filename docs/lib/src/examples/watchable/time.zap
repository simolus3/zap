<script>
  import 'package:zap/zap.dart';
</script>

<script context="library">
// Create a watchable backed by a stream emitting the current time every second.
final time = Watchable<DateTime>.stream(
  Stream.periodic(const Duration(milliseconds: 50), (_) => DateTime.now()),
  DateTime.now(),
);
</script>

<h1>The time is {watch(time)}</h1>
