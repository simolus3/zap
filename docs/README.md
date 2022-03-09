## docs

Documentation for `zap`, of course built with `build_runner`.

To view a dev build locally, run

```
dart run webdev serve pages:9999 web:8080 --auto refresh
```

and visit `http://localhost:8080`.

To view the MapBox example, you'll need a token which you can grab from
https://account.mapbox.com.
You can then run the build with

```
dart run webdev serve pages:9999 web:8080 --auto refresh -- '--define=build_web_compilers|ddc=environment={"MAPBOX_TOKEN": "your token"}'
```

To build the documentation as a static website, run

```
dart run webdev build --release -o
```
