import 'package:build/build.dart';

import 'src/builders/extract_api.dart';
import 'src/builders/generator.dart';
import 'src/builders/prepare.dart';

Builder preparing(BuilderOptions options) {
  return const PreparingBuilder();
}

Builder api(BuilderOptions options) {
  return const ApiExtractingBuilder();
}

Builder zapBuilder(BuilderOptions options) {
  return ZapBuilder(options.config['dev'] as bool);
}

PostProcessBuilder zapCleanup(BuilderOptions options) {
  return FileDeletingBuilder(const [
    '.tmp.zap.dart',
    '.tmp.zap.api.dart',
    '.tmp.zap.css',
    '.sass',
    '.scss',
  ], isEnabled: !(options.config['dev'] as bool));
}
