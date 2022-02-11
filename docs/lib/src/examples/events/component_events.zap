<script>
  import 'inner.zap';

  void handleMessage(CustomEvent event) {
    window.alert(event.detail as String);
  }
</script>

<inner on:message={handleMessage} />
