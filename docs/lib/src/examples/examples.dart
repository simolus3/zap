import 'package:collection/collection.dart';

class ExampleGroup {
  final String title;
  final List<ExampleComponent> children;

  const ExampleGroup({required this.title, required this.children});
}

class ExampleComponent {
  final String title;
  final String id;
  final List<String> files;

  const ExampleComponent(
      {required this.title, required this.id, required this.files});
}

const helloWorld = ExampleComponent(
  title: 'Hello world',
  id: 'hello-world',
  files: ['introduction/hello_world.zap'],
);
const styling = ExampleComponent(
  title: 'Styling',
  id: 'simple-styling',
  files: ['introduction/styling.zap'],
);
const nested = ExampleComponent(
  title: 'Nested components',
  id: 'simple-nested',
  files: [
    'introduction/nested/index.zap',
    'introduction/nested/nested.zap',
  ],
);
const rawHtml = ExampleComponent(
  title: '@html tags',
  id: 'raw-html',
  files: ['introduction/raw_html.zap'],
);

const reactiveAssignments = ExampleComponent(
  title: 'Reactive assignments',
  id: 'rx-assign',
  files: ['reactivity/assignments.zap'],
);
const reactiveDeclarations = ExampleComponent(
  title: 'Reactive declarations',
  id: 'rx-decl',
  files: ['reactivity/declarations.zap'],
);
const reactiveStatements = ExampleComponent(
  title: 'Reactive statements',
  id: 'rx-stmts',
  files: ['reactivity/statements.zap'],
);

const declaringProps = ExampleComponent(
  title: 'Declaring props',
  id: 'props-decl',
  files: ['props/nested_props.zap', 'props/props_1.zap'],
);
const defaultValues = ExampleComponent(
  title: 'Default values',
  id: 'props-default',
  files: ['props/nested_props.zap', 'props/props_2.zap'],
);

const ifBlocks = ExampleComponent(
  title: 'If blocks',
  id: 'blocks-if',
  files: ['logic/if_blocks.zap'],
);
const elseBlocks = ExampleComponent(
  title: 'Else blocks',
  id: 'blocks-else',
  files: ['logic/else_blocks.zap'],
);
const elseIfBlocks = ExampleComponent(
  title: 'Else-if blocks',
  id: 'blocks-elseif',
  files: ['logic/else_if.zap'],
);
const awaitBlocks = ExampleComponent(
  title: 'Await blocks',
  id: 'blocks-await',
  files: ['logic/await_blocks.zap'],
);
const eachBlocks = ExampleComponent(
  title: 'For blocks',
  id: 'blocks-for',
  files: ['logic/each_blocks.zap'],
);

const domEvents = ExampleComponent(
  title: 'DOM events',
  id: 'events-dom',
  files: ['events/dom_events.zap'],
);
const inlineHandler = ExampleComponent(
  title: 'Inline handler',
  id: 'events-inline',
  files: ['events/inline_handler.zap'],
);
const modifiers = ExampleComponent(
  title: 'Modifiers',
  id: 'events-modifiers',
  files: ['events/modifiers.zap'],
);
const componentEvents = ExampleComponent(
  title: 'Component events',
  id: 'events-components',
  files: ['events/component_events.zap', 'events/inner.zap'],
);
const eventForwarding = ExampleComponent(
  title: 'Event forwarding',
  id: 'events-forward',
  files: ['events/forwarding.zap', 'events/outer.zap', 'events/inner.zap'],
);
const domEventForwarding = ExampleComponent(
  title: 'DOM event forwarding',
  id: 'events-forward-dom',
  files: ['events/dom_forwarding.zap', 'events/custom_button.zap'],
);

const watchRead = ExampleComponent(
  title: 'Readable',
  id: 'watch-read',
  files: ['watchable/time.zap'],
);
const watchWrite = ExampleComponent(
  title: 'Writable',
  id: 'watch-write',
  files: [
    'watchable/sources.dart',
    'watchable/writable/counter.zap',
    'watchable/writable/decrementer.zap',
    'watchable/writable/incrementer.zap',
    'watchable/writable/resetter.zap',
  ],
);

const riverpodExample = ExampleComponent(
  title: 'MapBox with JS interop',
  id: 'mapbox',
  files: [
    'riverpod/example.zap',
    'riverpod/map.zap',
    'riverpod/marker.zap',
    'riverpod/mapbox.dart',
  ],
);

const examples = <ExampleGroup>[
  ExampleGroup(
    title: 'Introduction',
    children: [
      helloWorld,
      styling,
      nested,
      rawHtml,
    ],
  ),
  ExampleGroup(
    title: 'Reactivity',
    children: [
      reactiveAssignments,
      reactiveDeclarations,
      reactiveStatements,
    ],
  ),
  ExampleGroup(
    title: 'Props',
    children: [
      declaringProps,
      defaultValues,
    ],
  ),
  ExampleGroup(
    title: 'Logic',
    children: [
      ifBlocks,
      elseBlocks,
      elseIfBlocks,
      awaitBlocks,
      eachBlocks,
    ],
  ),
  ExampleGroup(
    title: 'Events',
    children: [
      domEvents,
      inlineHandler,
      modifiers,
      componentEvents,
      eventForwarding,
      domEventForwarding,
    ],
  ),
  ExampleGroup(
    title: 'Watchables',
    children: [
      watchRead,
      watchWrite,
    ],
  ),
  ExampleGroup(
    title: 'Riverpod',
    children: [riverpodExample],
  ),
];

ExampleComponent? componentFromId(String id) {
  return examples
      .expand((group) => group.children)
      .firstWhereOrNull((example) => example.id == id);
}
