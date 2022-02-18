## zap

Zap is a new, reactive web framework for Dart.

It enables to you write components with little overhead, with a compiler
transforming Dart scripts into reactive apps.

A simple counting button written in zap may look like this:

```html
<script>
  // Updates to this variable are reflected in the component
  // right away!
  var counter = 0;

  void handleClick() => counter++;
</script>

<button on:click={handleClick}>
  You've clicked this button { counter }
  { counter == 1 ? 'time' : 'times' }
</button>
```

For more information, including examples, please see https://simonbinder.eu/zap.

## Working on this package

The tests of this package rely on generated zap components too.
To run tests, run `dart run build_runner test` instead of `dart test`.
