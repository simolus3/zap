import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:zap_dev/src/generator/tree.dart';
import 'package:path/path.dart' show url;

import '../utils/dart.dart';

class ImportsTracker {
  final StringBuffer imports;
  final AssetId expectedOutput;
  final Map<Uri, String> _importPrefixes = {};

  ImportsTracker(GenerationScope scope, this.expectedOutput)
      : imports = scope.leaf();

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

  String importForUri(Uri uri) {
    uri = _normalizeUri(uri);

    return _importPrefixes.putIfAbsent(uri, () {
      final name = '_i${_importPrefixes.length}';
      imports.writeln('import ${dartStringLiteral(uri.toString())} as $name;');

      return name;
    });
  }

  String importForLibrary(LibraryElement element) {
    if (element.isInSdk) {
      final name = element.name.split('.').last;
      return importForUri(Uri.parse('dart:$name'));
    }

    return importForUri(element.source.uri);
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
