import 'package:build/build.dart';

import '../resolver/extract_api.dart';

class ApiExtractingBuilder implements Builder {
  const ApiExtractingBuilder();

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final output = buildStep.allowedOutputs.single;

    final library = await buildStep.inputLibrary;
    final function = library.topLevelFunctions.first;
    final functionNode = await buildStep.resolver.astNodeFor(
      function.firstFragment,
      resolve: true,
    );

    final api = writeApiForComponent(
      functionNode,
      await buildStep.readAsString(inputId),
      inputId.uri.toString(),
    );
    await buildStep.writeAsString(output, api);
  }

  @override
  Map<String, List<String>> get buildExtensions => {
    '.tmp.zap.dart': ['.tmp.zap.api.dart'],
  };
}
