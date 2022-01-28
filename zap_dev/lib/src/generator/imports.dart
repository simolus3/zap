import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:zap_dev/src/generator/tree.dart';
import 'package:path/path.dart' show url;

import '../utils/dart.dart';

class ImportsTracker {
  final StringBuffer imports;
  final AssetId expectedOutput;

  final Map<Uri, String> _importPrefixes = {};
  final Map<Uri, Set<String>> _unaliasedImports = {};

  ImportsTracker(GenerationScope scope, this.expectedOutput)
      : imports = scope.leaf();

  void ensureImportsAreWritten() {
    _unaliasedImports.forEach((import, shown) {
      final showCombinator = shown.join(', ');

      imports.writeln(
          'import ${dartStringLiteral(import.toString())} show $showCombinator;');
    });
  }

  String get dartHtmlImport => importForUri(Uri.parse('dart:html'));

  String get zapImport => importForUri(Uri.parse('package:zap/zap.dart'));

  Uri _normalizeUri(Uri uri) {
    if (uri.scheme == 'asset') {
      // Convert `asset` uri into `package:` uri if possible
      final asset = AssetId.resolve(uri);

      if (asset.path.startsWith('lib/')) {
        return asset.uri; // Will convert to `package`
      }

      return Uri.parse(
          url.relative(asset.path, from: url.dirname(expectedOutput.path)));
    }
    return uri;
  }

  /// Imports [show] from a library without an alias.
  ///
  /// This is used to import extension members with reasonable safety, as
  /// rewriting them to explicitly refer to the extension used is hard to do for
  /// cascade expressions.
  void importWithoutAlias(LibraryElement element, String show) {
    final uri = _normalizeUri(_uriFor(element));

    final shownElements = _unaliasedImports.putIfAbsent(uri, () => {});
    shownElements.add(show);
  }

  String importForUri(Uri uri) {
    uri = _normalizeUri(uri);

    return _importPrefixes.putIfAbsent(uri, () {
      final name = '_i${_importPrefixes.length}';
      imports.writeln('import ${dartStringLiteral(uri.toString())} as $name;');

      return name;
    });
  }

  Uri _uriFor(LibraryElement element) {
    if (element.isInSdk) {
      final name = element.name.split('.').last;
      return Uri.parse('dart:$name');
    }

    return element.source.uri;
  }

  String importForLibrary(LibraryElement element) {
    return importForUri(_uriFor(element));
  }

  /// The import for an element in a `.tmp.zap.api.dart` file.
  ///
  /// The import gets rewritten as if it pointed to `.zap.dart` as that's where
  /// the generated file will go to.
  String importForIntermediateLibrary(LibraryElement element) {
    final uri = element.source.uri;
    return importForUri(uri.replace(
      path: uri.path.replaceAll('.tmp.zap.api.dart', '.zap.dart'),
    ));
  }
}
