<script>
  import 'decrementer.zap';
  import 'incrementer.zap';
  import 'resetter.zap';

  import '../sources.dart';

  var countValue = watch(count);
</script>

<h1>The count is {countValue}</h1>

<incrementer />
<decrementer />
<resetter />
