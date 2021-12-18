import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p show url;
import 'package:sass_api/sass_api.dart' as sass;
// ignore: implementation_imports
import 'package:sass/src/async_compile.dart' as sassc;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:tuple/tuple.dart';

final _cache = Resource(() => _CachedStylesheets());

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
    final logger = _LoggerAsSassLogger(log);

    final result = await sassc.compileStringAsync(
      await buildStep.readAsString(buildStep.inputId),
      url: buildStep.inputId.uri,
      syntax: sass.Syntax.forPath(buildStep.inputId.path),
      importCache: _BuildAwareImportCache(
        cache: cache,
        importer: _BuildImporter(buildStep),
        logger: logger,
      ),
      logger: logger,
      style: output,
      sourceMap: true,
    );

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
        buildStep.writeAsString(mapOut, json.encode(result.sourceMap!.toJson()))
    ]);
  }
}

class _CachedStylesheets {
  final canonicalizeCache =
      <Tuple2<Uri, bool>, Tuple3<sass.AsyncImporter, Uri, Uri>?>{};
  final importCache = <Uri, sass.Stylesheet?>{};
  final resultsCache = <Uri, sass.ImporterResult>{};
}

// ignore: subtype_of_sealed_class
/// Version of an [AsyncImportCache] that uses an external [_CachedStylesheets]
/// instance to store cached data.
///
/// Effectively, this allows us to use an async import cache with build-step
/// specific importers that still caches information across build step.
class _BuildAwareImportCache implements sass.AsyncImportCache {
  final _CachedStylesheets _cache;
  final sass.AsyncImporter _importer;
  final sass.Logger _logger;

  _BuildAwareImportCache(
      {required _CachedStylesheets cache,
      required sass.AsyncImporter importer,
      required sass.Logger logger})
      : _cache = cache,
        _importer = importer,
        _logger = logger;

  @override
  Future<Tuple3<sass.AsyncImporter, Uri, Uri>?> canonicalize(
    Uri url, {
    sass.AsyncImporter? baseImporter,
    Uri? baseUrl,
    bool forImport = false,
  }) {
    final resolvedUri = baseUrl?.resolveUri(url) ?? url;

    // We don't support the legacy behavior around different canonicalization
    // for import uris.
    final query = Tuple2(resolvedUri, false);
    return _cache.canonicalizeCache.putIfAbsentAsync(query, () async {
      final canonical = await _importer.canonicalize(resolvedUri);
      if (canonical == null) {
        return null;
      }

      return Tuple3(_importer, canonical, resolvedUri);
    });
  }

  @override
  void clearCanonicalize(Uri url) {}

  @override
  void clearImport(Uri canonicalUrl) {}

  @override
  Uri humanize(Uri canonicalUrl) => canonicalUrl;

  @override
  Future<Tuple2<sass.AsyncImporter, sass.Stylesheet>?> import(Uri url,
      {sass.AsyncImporter? baseImporter,
      Uri? baseUrl,
      bool forImport = false}) async {
    final canonical = await canonicalize(url, baseUrl: baseUrl);
    if (canonical != null) {
      final stylesheet = await importCanonical(_importer, canonical.item2);
      if (stylesheet != null) {
        return Tuple2(_importer, stylesheet);
      }
    }
  }

  @override
  Future<sass.Stylesheet?> importCanonical(
      sass.AsyncImporter importer, Uri canonicalUrl,
      {Uri? originalUrl, bool quiet = false}) {
    return _cache.importCache.putIfAbsentAsync(canonicalUrl, () async {
      final result = await _importer.load(canonicalUrl);
      if (result == null) return null;

      _cache.resultsCache[canonicalUrl] = result;
      return sass.Stylesheet.parse(
        result.contents,
        result.syntax,
        url: canonicalUrl,
        logger: quiet ? sass.Logger.quiet : _logger,
      );
    });
  }

  @override
  Uri sourceMapUrl(Uri canonicalUrl) {
    final id = AssetId.resolve(
        _cache.resultsCache[canonicalUrl]?.sourceMapUrl ?? canonicalUrl);
    return id.servedUri ?? id.uri;
  }
}

class _BuildImporter extends sass.AsyncImporter {
  final AssetReader reader;

  _BuildImporter(this.reader);

  /// Returns potential asset ids for a sass [uri]:
  ///
  ///  - If [uri] points to a readable asset, returns that asset
  ///  - Otherwise, if [uri] but with a `_` before the basename points to a
  ///    readable asset, returns that asset.
  ///  - Otherwise, returns `null`
  Future<AssetId?> _readableAssetFor(AssetId id) async {
    if (await reader.canRead(id)) {
      return id;
    }

    final pathWithUnderscore =
        p.url.join(p.url.dirname(id.path) + '/_${p.url.basename(id.path)}');
    final withUnderscore = AssetId(id.package, pathWithUnderscore);
    if (await reader.canRead(withUnderscore)) {
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
      await reader.readAsString(import),
      sourceMapUrl: url,
      syntax: sass.Syntax.forPath(import.path),
    );
  }
}

/// Exports a logger from `package:logging` as a logger that can be used by
/// sass.
class _LoggerAsSassLogger implements sass.Logger {
  final Logger logger;

  _LoggerAsSassLogger(this.logger);

  @override
  void debug(String message, SourceSpan span) {
    final source = span.start.sourceUrl?.toString() ?? '<unknown source>';
    final line = span.start.line + 1;

    logger.fine('$source:$line: $message');
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

    logger.warning(buffer);
  }
}

extension<K, V> on Map<K, V> {
  Future<V> putIfAbsentAsync(K key, Future<V> Function() ifAbsent) async {
    if (containsKey(key)) return this[key] as V;
    var value = await ifAbsent();
    this[key] = value;
    return value;
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
