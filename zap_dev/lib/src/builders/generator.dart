import 'dart:async';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart' hide Resolver;
import 'package:build/build.dart' as build;
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import '../errors.dart';
import '../generator/generator.dart';
import '../generator/options.dart';
import '../resolver/dart_resolver.dart';
import '../resolver/preparation.dart';
import '../resolver/resolver.dart';
import '../utils/zap.dart';
import 'common.dart';

class ZapBuilder implements Builder {
  final bool isForDevelopment;

  const ZapBuilder(this.isForDevelopment);

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
    final componentName =
        dartComponentName(p.url.basenameWithoutExtension(input.path));

    final resolver = Resolver(
      prepResult,
      element,
      result.units.single.unit,
      ErrorReporter(reportError),
      componentName,
    );

    final dartResolver = _BuildDartResolver(buildStep.resolver);
    final component = await resolver.resolve(dartResolver);

    final options = GenerationOptions(isForDevelopment);
    final generator = Generator(component, prepResult, options, outId)..write();

    var output = generator.libraryScope.render();
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

class _BuildDartResolver implements DartResolver {
  final build.Resolver resolver;

  _BuildDartResolver(this.resolver);

  @override
  Future<LibraryElement> get dartHtml async {
    await for (final library in resolver.libraries) {
      if (library.name.contains('dart.') && library.name.contains('html')) {
        return library;
      }
    }

    throw StateError('Could not find `dart:html`?!');
  }

  @override
  Future<LibraryElement> resolveUri(Uri uri) {
    return resolver.libraryFor(AssetId.resolve(uri));
  }

  @override
  Future<Uri> uriForElement(Element element) async {
    return (await resolver.assetIdForElement(element)).uri;
  }
}
