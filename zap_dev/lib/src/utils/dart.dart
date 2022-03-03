import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

enum ImportRewriteMode {
  none,
  zapToApi,
  apiToGenerated,
}

class ScriptComponents {
  final List<String> originalImports;
  final String directives;
  final String body;

  ScriptComponents(this.originalImports, this.directives, this.body);

  factory ScriptComponents.of(String dartSource,
      {ImportRewriteMode rewriteImports = ImportRewriteMode.none}) {
    final content = parseString(content: dartSource, throwIfDiagnostics: false);
    final unit = content.unit;

    final directives = unit.directives;
    if (directives.isEmpty) {
      return ScriptComponents([], '', dartSource);
    } else {
      final directiveRewriter =
          _ZapToDartImportRewriter(dartSource, rewriteImports);
      for (final directive in directives) {
        directive.accept(directiveRewriter);
      }

      return ScriptComponents(
        directiveRewriter.originalDirectives,
        directiveRewriter.buffer.toString(),
        dartSource.substring(directiveRewriter.endOffset),
      );
    }
  }
}

const _dslLibrary = 'zap.internal.dsl';

bool isProp(VariableElement element) {
  return _findDslAnnotation(element, 'Property') != null;
}

/// Returns whether a element has the `$ComponentMarker` annotation.
///
/// This annotation is generated in the API-extracting builder for components
/// defined in a zap file.
String? componentTagName(Element element) {
  final annotation = _findDslAnnotation(element, r'$ComponentMarker');

  if (annotation != null) {
    return annotation.getField('tagName')!.toStringValue();
  }
  return null;
}

Iterable<String?> readSlotAnnotations(Element element) {
  return _findDslAnnotations(element, 'Slot').map((e) {
    final name = e.getField('name');

    if (name == null || name.isNull) {
      return null;
    } else {
      return name.toStringValue();
    }
  });
}

Iterable<Uri> additionalZapExports(
    Uri libraryUri, LibraryElement library) sync* {
  for (final meta in library.metadata) {
    final value = meta.computeConstantValue();
    if (value == null) continue;

    final type = value.type;
    if (type is! InterfaceType || type.element.name != 'pragma') {
      continue;
    }

    final name = value.getField('name')!.toStringValue();
    if (name != 'zap:additional_export') continue;

    for (final export in value.getField('options')!.toListValue()!) {
      yield libraryUri.resolve(export.toStringValue()!);
    }
  }
}

Iterable<DartObject> _findDslAnnotations(Element element, String className) {
  return element.metadata.map((annotation) {
    final value = annotation.computeConstantValue();
    if (value == null) return null;

    final type = value.type;
    if (type is! InterfaceType) return null;

    final backingClass = type.element;
    if (backingClass.name == className &&
        backingClass.library.name == _dslLibrary) {
      return value;
    }
  }).whereType();
}

DartObject? _findDslAnnotation(Element element, String className) {
  return _findDslAnnotations(element, className).firstOrNull;
}

bool isWatchFunctionFromDslLibrary(Identifier identifier) {
  final static = identifier.staticElement;
  if (static == null) return false;

  return static.library?.name == _dslLibrary && static.name == 'watch';
}

class _ZapToDartImportRewriter extends GeneralizingAstVisitor<void> {
  final String source;
  final StringBuffer buffer = StringBuffer();
  final List<String> originalDirectives = [];
  final ImportRewriteMode mode;

  int endOffset = 0;

  _ZapToDartImportRewriter(this.source, this.mode);

  @override
  void visitUriBasedDirective(UriBasedDirective node) {
    final start = node.offset;
    final end = endOffset = node.end;
    final uri = node.uri.stringValue;
    if (uri == null) return;

    originalDirectives.add(uri);
    final newImportString = rewriteUri(uri, mode);

    if (newImportString == uri) {
      // Just write the original import
      buffer.write(source.substring(start, end));
    } else {
      final stringStart = node.uri.offset;
      final stringEnd = node.uri.end;
      buffer
        ..write(source.substring(start, stringStart))
        ..write(dartStringLiteral(newImportString))
        ..write(source.substring(stringEnd, end));
    }
  }
}

String rewriteUri(String uri, ImportRewriteMode rewriteMode) {
  switch (rewriteMode) {
    case ImportRewriteMode.none:
      // Just keep the import as is
      break;
    case ImportRewriteMode.zapToApi:
      // Rewrite *.zap to *.tmp.zap.api.dart
      if (p.extension(uri) == '.zap') {
        return p.setExtension(uri, '.tmp.zap.api.dart');
      }
      break;
    case ImportRewriteMode.apiToGenerated:
      // Rewrite *.tmp.zap.api.dart to *.zap.dart
      const suffix = '.tmp.zap.api.dart';
      if (p.extension(uri, 4) == suffix) {
        return uri.substring(0, uri.length - suffix.length) + '.zap.dart';
      }
  }

  return uri;
}

String dartStringLiteral(String value) {
  final escaped = escapeForDart(value);
  return "'$escaped'";
}

String escapeForDart(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\$', '\\\$')
      .replaceAll('\r', '\\r')
      .replaceAll('\n', '\\n');
}
