import 'package:build/build.dart';
import 'package:zap_dev/src/builders/aggregate_css.dart';

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

Builder aggregateCss(BuilderOptions options) {
  final output = options.config['output']?.toString() ?? 'web/main.css';
  return AggregateCss(output);
}

PostProcessBuilder zapCleanup(BuilderOptions options) {
  return const FileDeletingBuilder([
    '.tmp.zap.dart',
    '.tmp.zap.api.dart',
    '.tmp.zap.css',
  ]);
}
