We currently use a three-step build process:

1. Component parsing: A `.zap` file is parsed into nodes defined in `lib/src/ast`.
   We focus on having accurate source spans for each components to enable good
   error reporting later.
   The result of this is called a `PrepareResult`.
   We also generate an artificial Dart file (`.tmp.zap.dart`) containing the
   source of `<script>` tags as well as expressions used in the DOM of the
   component. This file can be resolved later, allowing us to reason about
   used expressions.
2. Interface generation. Based on what we've seen in the prepare result, interfaces
   for defined components is generated as a `.api.tmp.zap.dart` file.
   The generated interfaces are looked up by the resolve step to know about
   imported components.
3. Resolving and generation: Based on the intermediate results from step 1 and 2,
   we can now resolve the component (e.g. figure out which variables update which
   parts of the DOM and make this `Flow` explicit) and generate the component class.
