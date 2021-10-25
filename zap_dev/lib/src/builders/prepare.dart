import 'package:build/build.dart';

import '../errors.dart';
import '../resolver/preparation.dart';
import 'common.dart';

class PreparingBuilder implements Builder {
  const PreparingBuilder();

  @override
  Future<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;
    final tempDart = input.changeExtension('.tmp.zap.dart');

    final errorReporter = ErrorReporter(reportError);

    final prepResult = await prepare(
        await buildStep.readAsString(input), input.uri, errorReporter);
    await buildStep.writeAsString(tempDart, prepResult.temporaryDartFile);
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.zap': ['.tmp.zap.dart'],
      };
}
