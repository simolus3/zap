import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;

import '../utils/dart.dart';
import '../utils/zap.dart';

class ApiExtractingBuilder implements Builder {
  const ApiExtractingBuilder();

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    var basename = p.basename(inputId.path);
    basename = basename.substring(0, basename.length - '.tmp.zap.dart'.length);
    final componentName = dartComponentName(basename);
    final output = buildStep.allowedOutputs.single;

    final library = await buildStep.inputLibrary;
    final function = library.definingCompilationUnit.functions.first;
    final functionNode =
        await buildStep.resolver.astNodeFor(function, resolve: true);

    final components = ScriptComponents.of(
        await buildStep.readAsString(buildStep.inputId),
        rewriteImports: ImportRewriteMode.none);

    final buffer = StringBuffer()
      ..writeln(components.directives)
      // Export the .tmp.zap.dart file, which contains definitions from a
      // `<script context="module">` definition. Those should be visible to
      // components importing this one.
      ..writeln("export '${inputId.uri}';")
      ..writeln("@\$ComponentMarker(${dartStringLiteral(basename)})")
      ..writeln('abstract class $componentName {');
    functionNode?.accept(_ApiInferrer(buffer));
    buffer.writeln('}');

    await buildStep.writeAsString(output, buffer.toString());
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.tmp.zap.dart': ['.tmp.zap.api.dart'],
      };
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
        final type = element.type.getDisplayString(withNullability: true);

        output
          ..write(type)
          ..write(' get ')
          ..write(element.name)
          ..writeln(';');

        if (!element.isFinal) {
          output
            ..write('set ')
            ..write(element.name)
            ..write('(')
            ..write(type)
            ..writeln(' value);');
        }
      }

      final slots = readSlotAnnotations(element).toList();

      if (slots.isNotEmpty) {
        for (final slot in slots) {
          output.writeln(
              '@Slot(${slot == null ? 'null' : dartStringLiteral(slot)})');
        }
        output.writeln('void get slots;');
      }
    }
  }
}
