<script>
  import 'package:zap/zap.dart';

  final currentTime = watch(time);
</script>

<script context="library">
// Create a watchable backed by a stream emitting the current time every second.
final time = Watchable<DateTime>.stream(
  Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
  DateTime.now(),
);
</script>

<h1>The time is {currentTime}</h1>
