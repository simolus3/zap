import 'package:build/build.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

class WriteVersions implements Builder {
  WriteVersions(BuilderOptions _);

  @override
  Map<String, List<String>> get buildExtensions => const {
        'pubspec.yaml': ['lib/src/getting_started/versions.dart'],
      };

  Future<void> build(BuildStep step) async {
    const packages = [
      'riverpod_zap',
      'zap',
      'zap_dev',
    ];

    final buffer = StringBuffer();

    for (final package in packages) {
      final pubspec = Pubspec.parse(
          await step.readAsString(AssetId(package, 'pubspec.yaml')));

      buffer.write("const $package = '${pubspec.version.toString()}';");
    }

    await step.writeAsString(step.allowedOutputs.single, buffer.toString());
  }
}
