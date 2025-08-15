import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' show url;

import '../utils/dart.dart';
import '../utils/zap.dart';

String writeApiForComponent(
  AstNode? functionNode,
  String temporaryDart,
  String uriOfTemporaryDart,
) {
  final components = ScriptComponents.of(
    temporaryDart,
    rewriteImports: ImportRewriteMode.none,
  );

  var basename = url.basename(uriOfTemporaryDart);
  basename = basename.substring(0, basename.length - '.tmp.zap.dart'.length);
  final componentName = dartComponentName(basename);

  final buffer = StringBuffer()
    ..writeln(components.directives)
    // Export the .tmp.zap.dart file, which contains definitions from a
    // `<script context="module">` definition. Those should be visible to
    // components importing this one.
    ..writeln("export '$uriOfTemporaryDart';")
    ..writeln("@\$ComponentMarker(${dartStringLiteral(basename)})")
    ..writeln('abstract class $componentName {');
  functionNode?.accept(_ApiInferrer(buffer));
  buffer.writeln('}');

  return buffer.toString();
}

class _ApiInferrer extends RecursiveAstVisitor<void> {
  final StringBuffer output;

  _ApiInferrer(this.output);

  @override
  void visitVariableDeclaration(VariableDeclaration declaration) {
    final element = declaration.declaredElement;

    if (element is LocalVariableElement) {
      if (isProp(element)) {
        // This variable denotes a property that can be set by other components.
        final type = element.type.getDisplayString();

        output
          ..write(type)
          ..write(' get ')
          ..write(element.name!)
          ..writeln(';');

        if (!element.isFinal) {
          output
            ..write('set ')
            ..write(element.name!)
            ..write('(')
            ..write(type)
            ..writeln(' value);');
        }
      }

      final slots = readSlotAnnotations(element).toList();

      if (slots.isNotEmpty) {
        for (final slot in slots) {
          output.writeln(
            '@Slot(${slot == null ? 'null' : dartStringLiteral(slot)})',
          );
        }
        output.writeln('void get slots;');
      }
    }
  }
}
