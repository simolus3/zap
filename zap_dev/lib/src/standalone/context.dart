import 'package:analyzer/dart/analysis/analysis_context.dart';

import 'file.dart';

class ZapAnalysisContext {
  final AnalysisContext dartContext;
  final List<RegisteredFile> ownedFiles = [];

  final bool analyzerKnowsAboutBuildWorkspace;

  ZapAnalysisContext(
    this.dartContext, {
    this.analyzerKnowsAboutBuildWorkspace = false,
  });
}
