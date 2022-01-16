<script>
  import 'outer.zap';

  void handleMessage(CustomEvent event) {
    window.alert(event.detail as String);
  }
</script>

<outer on:message={handleMessage} />
