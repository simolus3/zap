import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:tar/tar.dart';
import 'package:web/web.dart';
import 'versions.dart' as v;

void downloadExample(String packageName) {
  late List<int> tarFile;

  final writer = tarConverter.startChunkedConversion(
    ByteConversionSink.withCallback((result) => tarFile = result),
  );
  _TemplateFiles(packageName).writeInto(writer);
  writer.close();

  final blob = Blob(
    [(tarFile as Uint8List).toJS].toJS,
    BlobPropertyBag(type: 'application/x-tar'),
  );
  final url = URL.createObjectURL(blob);

  // To preserve the file name... https://stackoverflow.com/a/19328891/3260197
  final element = document.createElement('a') as HTMLAnchorElement
    ..href = url
    ..download = '$packageName.tar'
    ..style.visibility = 'none';
  document.body?.append(element);
  element.click();
  element.remove();
  URL.revokeObjectURL(url);
}

class _TemplateFiles {
  final String packageName;

  _TemplateFiles(this.packageName);

  void writeInto(Sink<SynchronousTarEntry> sink) {
    allEntries.forEach(sink.add);
  }

  SynchronousTarEntry _entry(String filename, String contents) {
    return TarEntry.data(
      TarHeader(
        name: '$packageName/$filename',
        userName: 'zap',
        groupName: 'zap',
        changed: DateTime.now(),
        mode: 420,
      ),
      utf8.encode(contents),
    );
  }

  Iterable<SynchronousTarEntry> get allEntries sync* {
    yield pubspec;
    yield readme;
    yield analysisOptions;

    yield* lib;
    yield* web;
  }

  SynchronousTarEntry get gitignore {
    return _entry('.gitignore', '''
# Files and directories created by pub.
.dart_tool/
.packages

# Conventional directory for build outputs.
build/

# Omit committing pubspec.lock for library packages; see
# https://dart.dev/guides/libraries/private-files#pubspeclock.
pubspec.lock
''');
  }

  SynchronousTarEntry get pubspec {
    return _entry('pubspec.yaml', '''
name: $packageName
publish_to: none
version: 0.1.0

environment:
  sdk: '>=3.8.2 <4.0.0'

dependencies:
  riverpod_zap:
    hosted: https://pub-simonbinder-eu.fsn1.your-objectstorage.com
    version: ^${v.riverpod_zap}
  web: ^1.1.1
  zap: ^${v.zap}

dev_dependencies:
  build_runner: ^2.6.0
  build_web_compilers: ^4.2.0
  sass_builder: ^2.2.2-dev.0
  lints: ^6.0.0
  zap_dev: ^${v.zap_dev}
''');
  }

  SynchronousTarEntry get analysisOptions {
    return _entry(
      'analysis_options.yaml',
      'include: package:lints/recommended.yaml\n',
    );
  }

  SynchronousTarEntry get readme {
    return _entry('README.md', '''
# $packageName

A simple web project based on zap.

## Running and deploying

To run this project, run `dart run build_runner serve --live-reload`.

To build this project, simply run `dart run webdev build`.

For more information on zap, please visit https://simonbinder.eu/zap/.
''');
  }

  Iterable<SynchronousTarEntry> get lib sync* {
    yield _entry('lib/src/state.dart', '''
import 'package:riverpod/riverpod.dart';

final counterProvider = StateNotifierProvider<Counter, int>((_) => Counter());

class Counter extends StateNotifier<int> {
  Counter() : super(0);

  void increment() => state++;
  void decrement() => state--;
  void reset() => state = 0;
}
''');

    yield _entry('lib/src/counter.zap', '''
<script>
  import 'package:riverpod_zap/riverpod.dart';
  import 'state.dart';

  var counter = watch(self.use(counterProvider));
</script>

<h1>{counter}</h1>
''');

    yield _entry('lib/src/buttons.zap', '''
<script>
  import 'package:riverpod_zap/riverpod.dart';
  import 'state.dart';

  final provider = self.read(counterProvider.notifier);
</script>

<style>
  button {
    color: red;
  }
</style>

<button on:click={provider.decrement}>-</button>
<button on:click={provider.increment}>+</button>
<button on:click={provider.reset}>reset</button>
''');

    yield _entry('lib/app.zap', '''
<script>
  import 'package:riverpod_zap/riverpod.dart';

  import 'src/counter.zap';
  import 'src/buttons.zap';
</script>

<riverpod-scope>
  <counter />
  <buttons />
</riverpod-scope>
''');
  }

  Iterable<SynchronousTarEntry> get web sync* {
    yield _entry('web/index.html', '''
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$packageName</title>
    <link rel="stylesheet" href="main.css">
    <script defer src="main.dart.js"></script>
</head>

<body></body>
</html>
''');

    yield _entry('web/main.dart', '''
import 'package:web/web.dart';

// This import will be available after running the build once.
import 'package:$packageName/app.zap.dart';

void main() {
  App().create(document.body!);
}
''');

    yield _entry('web/main.scss', '''
// By importing the styles for the root component, we also get the styles of
// every component used by it.
@use "package:$packageName/_app.zap";

''');
  }
}
