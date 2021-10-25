We currently use a three-step build process:

1. Component parsing: A `.zap` file is parsed into nodes defined in `lib/src/ast`.
   We focus on having accurate source spans for each components to enable good
   error reporting later.
2. 