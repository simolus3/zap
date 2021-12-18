import 'package:build/build.dart';
import 'package:sass_api/sass_api.dart' as s;

import 'src/builders/extract_api.dart';
import 'src/builders/generator.dart';
import 'src/builders/prepare.dart';
import 'src/builders/sass.dart';

Builder preparing(BuilderOptions options) {
  return const PreparingBuilder();
}

Builder api(BuilderOptions options) {
  return const ApiExtractingBuilder();
}

Builder zapBuilder(BuilderOptions options) {
  return ZapBuilder(options.config['dev'] as bool);
}

Builder sass(BuilderOptions options) {
  return SassBuilder(
    output: options.config['style'] == 'compressed'
        ? s.OutputStyle.compressed
        : s.OutputStyle.expanded,
    generateSourceMaps: (options.config['source_maps'] as bool?) ?? false,
  );
}

PostProcessBuilder zapCleanup(BuilderOptions options) {
  return FileDeletingBuilder(
    const [
      '.tmp.zap.dart',
      '.tmp.zap.api.dart',
      '.tmp.zap.css',
      '.sass',
      '.scss',
    ],
    isEnabled: !(options.config['dev'] as bool),
  );
}
