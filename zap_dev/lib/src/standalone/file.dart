import 'package:analyzer/file_system/file_system.dart';

import '../resolver/preparation.dart';
import '../resolver/resolver.dart';
import 'context.dart';

import '../errors.dart';

class RegisteredFile {
  final File file;
  final ZapAnalysisContext? context;

  RegisteredFile._(this.file, this.context) {
    context?.ownedFiles.add(this);
  }

  factory RegisteredFile(File file, ZapAnalysisContext? context) {
    if (file.provider.pathContext.extension(file.path) == '.zap') {
      return ZapFile._(file, context);
    } else {
      return RegisteredFile._(file, context);
    }
  }

  bool get isZapFile => false;
}

class ZapFile extends RegisteredFile {
  /// The state of this file.
  ///
  /// For zap files, we track states to analyze zap files in the right order.
  ZapFileState state = ZapFileState.dirty;
  List<RegisteredFile> imports = [];

  PrepareResult? prepareResult;
  ResolvedComponent? resolvedComponent;
  List<ZapError> errors = [];

  ZapFile._(File file, ZapAnalysisContext? context) : super._(file, context);

  @override
  bool get isZapFile => true;

  String get temporaryDartPath => _changeExtension('tmp.zap.dart');
  String get apiDartPath => _changeExtension('tmp.zap.api.dart');

  String _changeExtension(String newExtension) {
    final context = file.provider.pathContext;
    final withoutExtension = context.withoutExtension(file.path);

    return '$withoutExtension.$newExtension';
  }
}

enum ZapFileState {
  dirty,
  importsKnown,
  analyzed,
  error,
}
