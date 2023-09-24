<script>
    @prop
    String? val;

    String interpolated = '';

    $: interpolated = 'interpolated=$val, wrapped=${val}, isNull=${val == null}';
</script>

{interpolated}
