## docs

Documentation for `zap`, of course built with `build_runner`.

To view a dev build locally, run

```
dart run build_runner serve --live-reload
```

and visit `http://localhost:8080`.

To view the MapBox example, you'll need a token which you can grab from
https://account.mapbox.com.
You can then run the build with

```
dart run build_runner serve --live-reload --define=build_web_compilers|ddc=environment={"MAPBOX_TOKEN": "your token"}
```

To build the documentation as a static website, run

```
dart run build_runner build --release -o web:build
```
