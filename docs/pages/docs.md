---
template: layouts/main

data:
  title: Zap documentation
---

## Template syntax

### Tags

Zap components can include regular HTML elements.
When imported, other zap components can be included by using the basename of the
file they were declared in as a tag:

```html
<script>
  import 'headers.dart';
</script>

<headers />
```

### Text expressions

Inside of text or attributes, any Dart expression may be used in braces.

```html
<h1>Hello {name}!</h1>
<p>{a} + {b} = {a + b}.</p>
```

The expression will be evaluated and the result of calling `toString()` on the
result is escaped and inserted into the document.
When component variables used inside an expression change, the expression is
re-evaluated.

### {#if ...}

Content that is conditionally rendered can be wrapped in an if block.

```html
{#if answer === 42}
	<p>what was the question?</p>
{/if}
```

Additional conditions can be added with `{:else if expression}`, optionally
ending in an `{:else}` clause.

```html
#if porridge.temperature > 100}
	<p>too hot!</p>
{:else if 80 > porridge.temperature}
	<p>too cold!</p>
{:else}
	<p>just right!</p>
{/if}
```

As you'd expect, the expression used in an `if` or `else if` must be of type
`bool`.

### for blocks

A `for` block iterates over values:

```html
<script>
  const potentialQuestions = [
    'What is that beautiful house?',
    'Where does that highway go to?',
    'Am I right? Am I wrong?',
    'My God! What have I done?',
  ];
</script>

<h1>Potential questions</h1>

<ul>
  {#for question in potentialQuestions}
    <li>{question}</li>
  {/for}
</ul>
```

The type of the expression being iterated over must have a type of `Iterable<T>`.
The type of the loop variable is then inferred as `T`.
It is possible to keep track of indices by adding another loop variable:

```html
{#for question, i in potentialQuestions}
  { question }
  {#if i != potentialQuestions.length - 1}
    <hr>
  {/if}
{/for}
```

### `{#await ...}` and `{#await each ...}`

An `{#await x from expr }` block awaits the expression `expr`, which has to be of type
`FutureOr<T>`. The type of the variable `x` is then inferred to `ZapSnapshot<T>`.

An `{#await each x from expr}` block listens to a stream `expr`, which has to be of the
type `Stream<T>`. The type of the variable `x` is again inferred to `ZapSnapshot<T>`.

```html
<script>
  import 'dart:async';

  final stream = StreamController<String>().stream;
</script>

{#await each snapshot from stream}
  Hello {snapshot}
{/await}

{#await snapshot from stream.first}
  Hello {snapshot}
{/await}
```

### {@html ...}

Text written in zap components is escaped, so binding a string containing HTML
characters would escape characters like `<`and `>` in the component.

The `{@html }` block can be used to insert a Dart-expression __without any sanitazion__.
For example, `{@html "<script>alert('hacks');</script>"}` _will_ do what you may fear
it does. `{@html}` blocks should not be used with untrusted data.
Please note that the expression inside a block must be a full HTML node - things like
`{@html '<div>'}content{@html '</div>'}` won't work because `</div>` isn't valid HTML
on its own.
As contents are written directly into the DOM, zap components also can't be used inside
`{@html }` blocks.

### Element directives

In addition to regular attributes, elements can have _directives_, which control the
element's behavior in some way.

#### `on:eventname`

With the `on:` directive, a listener for DOM or component events can be registered.
The value of the directive must either be a `void Function()` or a `void Function(EventType)`,
where `EventType` depends on the name of the event used.
For instance, `on:Click` delivers a [`MouseEvent`][mouse].

```html
<script>
	var count = 0;

	void handleClick() => count++;
</script>

<button on:click={handleClick}>count: {count}</button>
```

Handlers can also be declare inline:

```html
<button on:click="{() => count++}">count: {count}</button>
```

Modifiers can be added to the event stream with the `|` character:

```html
<form on:submit|preventDefault={handleSubmit}>
	<!-- the `submit` event's default is prevented,
	     so the page won't reload -->
</form>
```

The following modifiers are available:

- `preventDefault`: calls `event.preventDefault()` before running the handler.
- `stopPropagation`: calls `event.stopProgataion()`, preventing the event from
  reaching the next element.
- `passive`: TODO this is currently a noop
- `capture`: Fires the handler during the _capture_ phase instead of the _bubbling_
  phase.
- `once`: Remove the handler after the first time it runs.
- `self`: Only trigger the handler if `event.target` is the element itself.
- `trusted`. Only trigger the handler if `event.isTrusted` is `true`.

Modifiers can be chained together, e.g. `on:click|once|capture={...}`.

It is possible to have multiple event listeners for the same event.

#### `bind:property`

Data ordinarily flows down, from parent to child. The `bind:` directive allows
data to flow the other way, from chil to parent. Most bindings are specific to
particular elements.

The simplest bindings reflect the value of a property, such as `input.value`:

```html
<input bind:value={name}>
<textarea bind:value={text}></textarea>

<input type="checkbox" bind:checked={yes}>
```

Zap does not currently support the shorthand syntax or known types other than
`String`. Contributions are welcome!

[mouse]: https://api.dart.dev/stable/2.16.1/dart-html/MouseEvent-class.html

#### `bind:this`

To get a reference to a DOM node, use `bind:this`:

```html
<script>
	late CanvasElement canvas;

	onMount(() => {
		const ctx = canvasElement.getContext('2d');
		drawStuff(ctx);
	});
  self.onMount(() {
    final context = canvas.context2D;
    drawStuff(context);
  });
</script>

<canvas bind:this={canvasElement}></canvas>
```

### `<slot>`

Components can have child content, in the same way that elements can.

The content is exposed in the child component using the `<slot>` element,
which can contain fallback content that is rendered if no children are
provided.

```html
<!-- widget.zap -->
<div>
	<slot>
		this fallback content will be rendered when no content is provided, like in the first example
	</slot>
</div>

<!-- app.zap -->
<widget></widget> <!-- this component will render the default content -->

<widget>
	<p>this is some child content that will overwrite the default slot content</p>
</widget>
```

#### Named slots

Named slots allow consumers to target specific areas. They can also have fallback content.

```html
<!-- widget.zap -->
<div>
	<slot name="header">No header was provided</slot>
	<p>Some content between header and footer</p>
	<slot name="footer"></slot>
</div>

<!-- app.zap -->
<widget>
	<h1 slot="header">Hello</h1>
	<p slot="footer">Copyright (c) {{ site.copyright_year }} Zap Industries</p>
</widget>
```

#### `<zap:fragment>`

The special `<zap:fragment>` tag can be used to place multiple DOM nodes in a slot
without wrapping it in a container element:

```html
<widget>
	<h1 slot="header">Hello</h1>
	<zap:fragment slot="footer">
    <p>All rights reserved.</p>
    <p>Copyright (c) {{ site.copyright_year }} Zap Industries</p>
  </zap:fragment>
</widget>
```

### Dynamic components

To include a child component that's not known statically, the special `<zap:component>`
tag can be used:

```html
<zap:component this={currentSelection.component}/>
```

## Runtime API

### Lifecycle

Inside a component script, you can use the special `self` variable to refer to
the component.
It contains the following important members:

- `Map<Object?, Object?> get context`:
- `void emitEvent(Event event)`: Allows emitting custom component events that
  parent components can listen to with the `on:` directive.
- `Future<void> get tick`: A future completing after pending state changes have been
  applied. If no state changes are scheduled, the returned future returns in a new
  microtask.

### Watchables

To support reactivity, especially with complex flows across components, zap
provides a concept of `Watchable`s.
A `Watchable` is essentially a stream that never emits errors, and always
provides the latest value through a `value` getter.

```dart
final currentTime = Watchable.stream(
  Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
  DateTime.now()
);
```

Inside components, the `watch` function can be used to read the current value of
a `Watchable`. When the watchable updates, so will the parts of the component
reading that watchable.
__TODO__: At the moment, `watch` can only be used in an assignment to variables.
This could be expanded to also allow using `watch` inside text expressions.

```html
<script>
  final now = watch(currentTime);
</script>

The current time is {now}.
```

### Context

## Riverpod Zap

Zap has a first-class package providing integration with [Riverpod](https://riverpod.dev/),
a reactive framework for state management.

To use it, depend on `riverpod_zap`:

```yaml
dependencies:
  riverpod_zap:
    hosted: https://simonbinder.eu
```

To use riverpod providers in zap components, import `package:riverpod_zap/riverpod.dart`.
It provides the following extensions for components:

- `ProviderContainer self.riverpodContainer`: The container of the closest riverpod scope surrounding this component.
- `T self.read<T>(ProviderBase<T> provider)`: Reads the value of a provider.
- `Watchable<State> use<T>(ProviderListenable<T> provider)`: Obtains the updating value of a provider as a `Watchable`.
  It can be used together with [watch](#watchables) to automatically listen for the latest value of a provider.

To register a new riverpod scope, import `package:riverpod_zap/riverpod-scope.zap`
and use the `<riverpod-scope>` tag in a component.
