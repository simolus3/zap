import 'package:jaspr/jaspr.dart';
import 'package:zap/zap.dart';

import 'introduction/hello_world.zap.dart' as intro;
import 'introduction/styling.zap.dart' as intro;
import 'introduction/nested/index.zap.dart' as intro;
import 'introduction/raw_html.zap.dart' as intro;

import 'reactivity/assignments.zap.dart' as rx;
import 'reactivity/declarations.zap.dart' as rx;
import 'reactivity/statements.zap.dart' as rx;

import 'props/props_1.zap.dart' as props;
import 'props/props_2.zap.dart' as props;

import 'logic/if_blocks.zap.dart' as logic;
import 'logic/else_blocks.zap.dart' as logic;
import 'logic/else_if.zap.dart' as logic;
import 'logic/await_blocks.zap.dart' as logic;
import 'logic/each_blocks.zap.dart' as logic;

import 'events/dom_events.zap.dart' as events;
import 'events/inline_handler.zap.dart' as events;
import 'events/modifiers.zap.dart' as events;
import 'events/component_events.zap.dart' as events;
import 'events/forwarding.zap.dart' as events;
import 'events/dom_forwarding.zap.dart' as events;

import 'watchable/time.zap.dart' as watch;
import 'watchable/writable/counter.zap.dart' as watch;

import 'riverpod/example.zap.dart' as riverpod;

import 'examples.dart';

final selectedComponent = WritableWatchable(examples.first.children.first);

Component instantiate(ExampleComponent component) {
  switch (component) {
    case helloWorld:
      return intro.HelloWorld();
    case styling:
      return intro.Styling();
    case nested:
      return intro.Index();
    case rawHtml:
      return intro.RawHtml();

    case reactiveAssignments:
      return rx.Assignments();
    case reactiveDeclarations:
      return rx.Declarations();
    case reactiveStatements:
      return rx.Statements();

    case declaringProps:
      return props.Props1();
    case defaultValues:
      return props.Props2();

    case ifBlocks:
      return logic.IfBlocks();
    case elseBlocks:
      return logic.ElseBlocks();
    case elseIfBlocks:
      return logic.ElseIf();
    case awaitBlocks:
      return logic.AwaitBlocks();
    case eachBlocks:
      return logic.EachBlocks();

    case domEvents:
      return events.DomEvents();
    case inlineHandler:
      return events.InlineHandler();
    case modifiers:
      return events.Modifiers();
    case componentEvents:
      return events.ComponentEvents();
    case eventForwarding:
      return events.Forwarding();
    case domEventForwarding:
      return events.DomForwarding();

    case watchRead:
      return watch.Time();
    case watchWrite:
      return watch.Counter();

    case riverpodExample:
      return riverpod.Example();

    default:
      throw StateError('Unknown example ${component.id}!');
  }
}
