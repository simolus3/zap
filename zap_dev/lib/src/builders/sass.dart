import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:path/path.dart' as p show url;
import 'package:sass_api/sass_api.dart' as sass;
// ignore: implementation_imports
import 'package:sass/src/async_compile.dart' as sassc;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

final _cache = Resource(
  () => sass.AsyncImportCache(
    importers: [_BuildImporter()],
    logger: const _BuildSassLogger(),
  ),
);

/// A builder compiling `.sass` and `.scss` files to `.css` files.
///
/// This builder has been inspired from the `sass_builder` package. Unlike that
/// package, is supports caching parse results across build steps, emits source
/// mappings and is more actively maintained.
class SassBuilder extends Builder {
  final sass.OutputStyle output;
  final bool generateSourceMaps;

  SassBuilder({required this.output, required this.generateSourceMaps});

  @override
  Map<String, List<String>> get buildExtensions {
    return {
      '.sass': ['.css', '.css.map'],
      '.scss': ['.css', '.css.map'],
    };
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    if (p.url.basename(buildStep.inputId.path).startsWith('_')) {
      log.fine('Skip! Input starts with an underscore');
      return;
    }

    final cache = await buildStep.fetchResource(_cache);
    final contents = await buildStep.readAsString(buildStep.inputId);

    final result = await _BuildImporter.withReader(() {
      return sassc.compileStringAsync(
        contents,
        url: buildStep.inputId.uri,
        syntax: sass.Syntax.forPath(buildStep.inputId.path),
        importCache: cache,
        logger: const _BuildSassLogger(),
        style: output,
        sourceMap: generateSourceMaps,
      );
    }, buildStep);

    // Some sources may have been read from cache. Make sure we dispatch them
    // to the build system for deterministic builds!
    await Future.wait(
        result.loadedUrls.map(AssetId.resolve).map(buildStep.canRead));

    final cssOut = buildStep.inputId.changeExtension('.css');
    final mapOut = buildStep.inputId.changeExtension('.css.map');

    final cssContent = StringBuffer(result.css);
    if (generateSourceMaps) {
      cssContent
        ..writeln()
        ..writeln('/*# sourceMappingURL=${p.url.basename(mapOut.path)}*/');
    }

    await Future.wait([
      buildStep.writeAsString(cssOut, cssContent.toString()),
      if (generateSourceMaps)
        buildStep.writeAsString(
            mapOut,
            json
                .encode(result.sourceMap!.toJson())
                .replaceAll('http://source_maps', ''))
    ]);
  }
}

class _BuildImporter extends sass.AsyncImporter {
  static const _readerZoneKey = #zap_dev.sass.reader;

  static T withReader<T>(T Function() body, AssetReader reader) {
    return runZoned(body, zoneValues: {_readerZoneKey: reader});
  }

  AssetReader get _reader => Zone.current[_readerZoneKey] as AssetReader;

  /// Returns potential asset ids for a sass [uri]:
  ///
  ///  - If [uri] points to a readable asset, returns that asset
  ///  - Otherwise, if [uri] but with a `_` before the basename points to a
  ///    readable asset, returns that asset.
  ///  - Otherwise, returns `null`
  Future<AssetId?> _readableAssetFor(AssetId id) async {
    if (await _reader.canRead(id)) {
      return id;
    }

    final pathWithUnderscore =
        p.url.join(p.url.dirname(id.path) + '/_${p.url.basename(id.path)}');
    final withUnderscore = AssetId(id.package, pathWithUnderscore);
    if (await _reader.canRead(withUnderscore)) {
      return withUnderscore;
    }
  }

  @override
  FutureOr<Uri?> canonicalize(Uri url) async {
    final originalAsset = AssetId.resolve(url);
    final extension = originalAsset.extension;
    if (extension == '.sass' || extension == '.scss') {
      return (await _readableAssetFor(originalAsset))?.uri;
    }

    // Attempt to add the extension then
    final candidates = [
      originalAsset.addExtension('.sass'),
      originalAsset.addExtension('.scss')
    ];
    for (final candidate in candidates) {
      final readable = await _readableAssetFor(candidate);
      if (readable != null) {
        return readable.uri;
      }
    }
  }

  @override
  FutureOr<sass.ImporterResult?> load(Uri url) async {
    final import = AssetId.resolve(url);
    return sass.ImporterResult(
      await _reader.readAsString(import),
      sourceMapUrl:
          import.servedUri?.replace(scheme: 'http', host: 'source_maps'),
      syntax: sass.Syntax.forPath(import.path),
    );
  }
}

/// Exports a logger from `package:logging` as a logger that can be used by
/// sass.
class _BuildSassLogger implements sass.Logger {
  const _BuildSassLogger();

  @override
  void debug(String message, SourceSpan span) {
    final source = span.start.sourceUrl?.toString() ?? '<unknown source>';
    final line = span.start.line + 1;

    log.fine('$source:$line: $message');
  }

  @override
  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false}) {
    final buffer = StringBuffer();
    if (deprecation) {
      buffer.write('Deprecation warning');
    } else {
      buffer.write('Warning');
    }

    if (span == null) {
      buffer.write(': $message');
    } else {
      buffer.write('on ${span.message(message, color: false)}');
    }

    log.warning(buffer);
  }
}

extension on AssetId {
  /// Returns a probable uri of this asset when served through `webdev serve`.
  Uri? get servedUri {
    if (p.url.isWithin('web/', path)) {
      // Assets in `web/` are served under `/`.
      return Uri(path: p.url.relative(path, from: 'web/'));
    } else if (p.url.isWithin('lib/', path)) {
      // Assets in `lib/` are served under `/packages/<package/`.
      return Uri(
          path: '/packages/$package/${p.url.relative(path, from: 'lib/')}');
    }
  }
}
