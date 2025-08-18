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
        'import ${dartStringLiteral(import.toString())} show $showCombinator;',
      );
    });
  }

  String get packageWebImport =>
      importForUri(Uri.parse('package:web/web.dart'));

  String get zapImport => importForUri(Uri.parse('package:zap/zap.dart'));

  Uri _normalizeUri(Uri uri) {
    // `.tmp.zap.api.dart` files expose members defined in
    // `<script module="library">` tags, which are also copied into the final
    // `.zap.dart` file. We always want to use the later to avoid members being
    // defined twice.
    if (url.extension(uri.path, 4) == '.tmp.zap.api.dart') {
      uri = uri.replace(
        path: uri.path.replaceAll('.tmp.zap.api.dart', '.zap.dart'),
      );
    } else if (url.extension(uri.path, 3) == '.tmp.zap.dart') {
      uri = uri.replace(
        path: uri.path.replaceAll('.tmp.zap.dart', '.zap.dart'),
      );
    }

    if (uri.scheme == 'asset') {
      // Convert `asset` uri into `package:` uri if possible
      final asset = AssetId.resolve(uri);

      if (asset.path.startsWith('lib/')) {
        return asset.uri; // Will convert to `package`
      }

      return Uri.parse(
        url.relative(asset.path, from: url.dirname(expectedOutput.path)),
      );
    }
    return uri;
  }

  /// Imports [show] from a library without an alias.
  ///
  /// This is used to import extension members with reasonable safety, as
  /// rewriting them to explicitly refer to the extension used is hard to do for
  /// cascade expressions.
  void importWithoutAlias(LibraryElement element, String show) {
    final uri = _normalizeUri(element.uri);

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

  String importForLibrary(LibraryElement element) {
    return importForUri(element.uri);
  }
}
