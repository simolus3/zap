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
  return const ZapBuilder();
}

PostProcessBuilder zapCleanup(BuilderOptions options) {
  return const FileDeletingBuilder([
    '.tmp.zap.dart',
    '.tmp.zap.api.dart',
  ]);
}
