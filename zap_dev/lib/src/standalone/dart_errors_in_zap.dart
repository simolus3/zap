import 'package:analyzer/error/error.dart';

import '../errors.dart';
import '../resolver/dart.dart';
import '../resolver/preparation.dart';
import '../resolver/resolver.dart';

/// Maps analysis errors reported on the helper `.tmp.zap.dart` file into
/// errors on the zap file.
///
/// Dart errors in `<script>` tags are reported as such. Errors originating from
/// inline Dart expressions in other parts of zap files are also mapped.
class MapDartErrorsInZapFile {
  final PrepareResult prepareResult;
  final ResolvedComponent component;
  final ErrorReporter reporter;

  MapDartErrorsInZapFile(this.prepareResult, this.component, this.reporter);

  void reportErrors(List<AnalysisError> errors) => errors.forEach(_mapError);

  bool _errorIsRelevant(AnalysisError error) {
    if (error.errorCode.uniqueName.contains('LATE')) {
      // we move variables around a lot, so late variable analysis doesn't
      // really work at the moment
      return false;
    }

    switch (error.errorCode.name) {
      case 'UNUSED_IMPORT':
      case 'URI_DOES_NOT_EXIST':
        // These imports are added to analyze external components, ignore
        return !error.message.contains('zap');
      case 'UNUSED_LABEL':
        // The `$` label has a meaning in zap
        return !error.message.contains(r"'$'");
      case 'NOT_ASSIGNED_POTENTIALLY_NON_NULLABLE_LOCAL_VARIABLE':
        // If this warning refers to a `@prop` variable, it will be initialized.
        final refersToProperty = component.component.scope.declaredVariables
            .where((v) => v is DartCodeVariable && v.isProperty)
            .any((v) => error.message.contains("'${v.element.name}'"));
        return !refersToProperty;
    }

    return true;
  }

  void _mapError(AnalysisError error) {
    final region = prepareResult.temporaryDartFile.regionAt(error.offset);
    if (region == null || !region.createdForNode.hasSpan) return;

    if (!_errorIsRelevant(error) ||
        region.endOffsetExclusive < error.offset + error.length) {
      // This error spans multiple regions, so we can't map it to one zap
      // node.
      return;
    }

    final nodeSpan = region.createdForNode.span;
    final offsetRelativeToNode = error.offset - region.startOffset;
    final offsetRelativeToSourceFile =
        nodeSpan.start.offset + offsetRelativeToNode + region.startOffsetInNode;

    final errorSpan = nodeSpan.file.span(
      offsetRelativeToSourceFile,
      offsetRelativeToSourceFile + error.length,
    );

    reporter.reportError(
      ZapError('${error.errorCode.uniqueName} ${error.message}', errorSpan),
    );
  }
}
