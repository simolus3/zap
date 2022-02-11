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

const helloWorld =
    ExampleComponent(title: 'Hello world', id: 'hello-world', files: []);
const styling =
    ExampleComponent(title: 'Styling', id: 'simple-styling', files: []);
const nested = ExampleComponent(
    title: 'Nested components', id: 'simple-nested', files: []);
const rawHtml =
    ExampleComponent(title: '@html tags', id: 'raw-html', files: []);

const reactiveAssignments =
    ExampleComponent(title: 'Reactive assignments', id: 'rx-assign', files: []);
const reactiveDeclarations =
    ExampleComponent(title: 'Reactive declarations', id: 'rx-decl', files: []);
const reactiveStatements =
    ExampleComponent(title: 'Reactive statements', id: 'rx-stmts', files: []);

const declaringProps =
    ExampleComponent(title: 'Declaring props', id: 'props-decl', files: []);
const defaultValues =
    ExampleComponent(title: 'Default values', id: 'props-default', files: []);

const ifBlocks =
    ExampleComponent(title: 'If blocks', id: 'blocks-if', files: []);
const elseBlocks =
    ExampleComponent(title: 'Else blocks', id: 'blocks-else', files: []);
const elseIfBlocks =
    ExampleComponent(title: 'Else-if blocks', id: 'blocks-elseif', files: []);
const awaitBlocks =
    ExampleComponent(title: 'Await blocks', id: 'blocks-await', files: []);
const eachBlocks =
    ExampleComponent(title: 'For blocks', id: 'blocks-for', files: []);

const domEvents =
    ExampleComponent(title: 'DOM events', id: 'events-dom', files: []);
const inlineHandler =
    ExampleComponent(title: 'Inline handler', id: 'events-inline', files: []);
const modifiers =
    ExampleComponent(title: 'Modifiers', id: 'events-modifiers', files: []);
const componentEvents = ExampleComponent(
    title: 'Component events', id: 'events-components', files: []);
const eventForwarding = ExampleComponent(
    title: 'Event forwarding', id: 'events-forward', files: []);
const domEventForwarding = ExampleComponent(
    title: 'DOM event forwarding', id: 'events-forward-dom', files: []);

const watchRead =
    ExampleComponent(title: 'Readable', id: 'watch-read', files: []);
const watchWrite =
    ExampleComponent(title: 'Writable', id: 'watch-write', files: []);

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
];

ExampleComponent? componentFromId(String id) {
  return examples
      .expand((group) => group.children)
      .firstWhereOrNull((example) => example.id == id);
}
