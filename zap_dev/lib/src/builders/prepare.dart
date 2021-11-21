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
    final tempCss = input.changeExtension('.tmp.zap.css');

    final errorReporter = ErrorReporter(reportError);

    final prepResult = await prepare(
        await buildStep.readAsString(input), input.uri, errorReporter);
    await buildStep.writeAsString(tempDart, prepResult.temporaryDartFile);

    final css = prepResult.cssFile;
    if (css != null) {
      await buildStep.writeAsString(tempCss, css);
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.zap': ['.tmp.zap.dart', '.tmp.zap.css'],
      };
}
