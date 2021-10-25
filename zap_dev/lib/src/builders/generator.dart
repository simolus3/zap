import 'dart:async';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import '../errors.dart';
import '../generator.dart';
import '../resolver/preparation.dart';
import '../resolver/resolver.dart';
import 'common.dart';

class ZapBuilder implements Builder {
  const ZapBuilder();

  @override
  Future<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;
    final tempDart = input.changeExtension('.tmp.zap.dart');
    final outId = input.changeExtension('.zap.dart');

    final errorReporter = ErrorReporter(reportError);

    final prepResult = await prepare(
        await buildStep.readAsString(input), input.uri, errorReporter);

    final element = await buildStep.resolver.libraryFor(tempDart);
    // Todo: Use astNodeFor here, but we'll have to obtain a suitable element
    // first.
    final result = await element.session.getResolvedLibraryByElement(element)
        as ResolvedLibraryResult;

    final component = await resolveComponent(
      prepResult,
      element,
      result.units.single.unit,
      ErrorReporter(reportError),
      buildStep,
    );

    final componentName = p.url.basenameWithoutExtension(input.path);

    final generator = Generator(componentName, prepResult, component)..write();

    var output = generator.buffer.toString();
    try {
      output = DartFormatter().format(output);
    } on FormatterException {
      log.warning('Could not format generated output, this is probably a bug '
          'in zap_dev.');
    }

    await buildStep.writeAsString(outId, output);
  }

  @override
  Map<String, List<String>> get buildExtensions {
    return const {
      '.zap': ['.zap.dart'],
    };
  }
}
