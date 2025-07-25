import 'package:analyzer/dart/element/element2.dart';

/// An abstraction over Dart-resolving capabilities of the `build` system and
/// the internal tooling used by `zap_dev`.
///
/// This allows sharing the complex resolve logic between build steps and the
/// CLI linter / analysis plugin.
abstract class DartResolver {
  Future<LibraryElement2> get packageWeb;

  Future<LibraryElement2> resolveUri(Uri uri);

  /// The package uri under which [element] is available.
  ///
  /// Throws when the [element] has no clear URI.
  Future<Uri> uriForElement(Element2 element);
}
