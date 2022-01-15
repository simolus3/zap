import 'package:build/build.dart';
import 'package:glob/glob.dart';

class AggregateStyles implements Builder {
  AggregateStyles([BuilderOptions? options]);

  @override
  Map<String, List<String>> get buildExtensions => {
        r'lib/$lib$': ['web/style.scss']
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final buffer = StringBuffer();

    var i = 0;
    await for (final asset in buildStep.findAssets(Glob('**/*.scss'))) {
      buffer.writeln('@use "${asset.uri}" as i${i++};');
    }

    await buildStep.writeAsString(
        buildStep.allowedOutputs.single, buffer.toString());
  }
}
