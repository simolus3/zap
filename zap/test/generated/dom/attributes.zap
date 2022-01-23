<script>
  @prop
  var enabled = true;

  @prop
  var classes = 'a';

  @prop
  late String? another;
</script>
<style>
 .a { color: red; }
</style>

<input disabled={!enabled} x-another={another} />
<span class={classes}></span>
