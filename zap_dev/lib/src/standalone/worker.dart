import 'dart:async';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:pool/pool.dart';

import '../errors.dart';
import '../resolver/dart_resolver.dart';
import '../resolver/extract_api.dart';
import '../resolver/preparation.dart';
import '../resolver/resolver.dart';
import 'analyzer_hacks.dart';
import 'context.dart';
import 'dart_errors_in_zap.dart';
import 'file.dart';

class ZapWorker {
  final Map<String, RegisteredFile> _files = {};
  final List<ZapAnalysisContext> _contexts = [];

  final ResourceProvider _underlyingProvider;
  final OverlayResourceProvider _overlayFs;
  late final ResourceProvider _providerForDartAnalyzer;

  final Pool _pool = Pool(1);

  final StreamController<ZapFile> _finishedAnalysis =
      StreamController.broadcast();

  ZapWorker(this._underlyingProvider)
    : _overlayFs = OverlayResourceProvider(_underlyingProvider) {
    _providerForDartAnalyzer = HideGeneratedBuildFolder(_overlayFs);
  }

  Stream<ZapFile> get analyzedFiles => _finishedAnalysis.stream;

  ZapAnalysisContext newContext(String root, [List<String>? exclude]) {
    final collection = AnalysisContextCollection(
      includedPaths: [root],
      excludedPaths: exclude,
      // Run Dart analysis on the overlay where we register temporary Dart files
      // used to analyze inline Dart expression.
      resourceProvider: _providerForDartAnalyzer,
    );

    final context = collection.contextFor(root);
    final zapContext = ZapAnalysisContext(context);

    _contexts.add(zapContext);
    return zapContext;
  }

  ZapAnalysisContext? contextFor(String path) {
    for (final context in _contexts) {
      if (context.dartContext.contextRoot.isAnalyzed(path)) {
        return context;
      }
    }
  }

  RegisteredFile file(String path) {
    if (_files.containsKey(path)) {
      return _files[path]!;
    }

    final context = contextFor(path);

    return _files[path] = RegisteredFile(
      _underlyingProvider.getFile(path),
      context,
    );
  }

  void closeContext(ZapAnalysisContext context) {
    assert(_contexts.contains(context));
    _contexts.remove(context);

    for (final file in context.ownedFiles) {
      _files.remove(file.file.path);
    }
  }

  Future<void> analyze(RegisteredFile file) async {
    if (file is ZapFile && file.context != null) {
      await _prepareIfNeeded(file);

      // Also wait for all dependencies to be prepared.
      await Future.wait([
        for (final dependency in file.imports) _prepareIfNeeded(dependency),
      ]);

      await _resolve(file);
    }
  }

  /// Prepares a file for analyis if the file is a zap file and needs a
  /// preparation run.
  ///
  /// A file is prepared if it has changed since it was last prepared. After
  /// being prepared, the temporary Dart files used to resolve inline Dart
  /// expression and to export the component's API are set up.
  Future<void> _prepareIfNeeded(RegisteredFile file) {
    return _pool.withResource(() async {
      if (file.context != null &&
          file is ZapFile &&
          file.state == ZapFileState.dirty) {
        await _prepare(file);
      }
    });
  }

  Future<void> _prepare(ZapFile file) async {
    file.errors.clear();

    final source = file.file.readAsStringSync();
    final uri = file.file.toUri();
    final result = await prepare(source, uri, _reportErrorsInFile(file));

    final dartContext = file.context!.dartContext;
    final urlConverter = dartContext.currentSession.uriConverter;
    final ownUrl = urlConverter.pathToUri(file.file.path) ?? file.file.toUri();

    file.prepareResult = result;
    file.imports = [
      for (final path in result.importedZapFiles)
        this.file(urlConverter.uriToPath(ownUrl.resolve(path))!),
    ];

    final now = DateTime.now().millisecondsSinceEpoch;

    // Write the hidden Dart file used to resolve DOM expressions into a
    // the overlay FS.
    _overlayFs.setOverlay(
      file.temporaryDartPath,
      content: result.temporaryDartFile.contents,
      modificationStamp: now,
    );

    // Now that the temporary file exists, we can resolve it to export the API
    // and read imports.
    final unit = await dartContext.currentSession.getResolvedUnit(
      file.temporaryDartPath,
    );
    if (unit is ResolvedUnitResult) {
      final export = file.file.provider.pathContext.basename(
        file.temporaryDartPath,
      );

      final function = unit.unit.declarations
          .whereType<FunctionDeclaration>()
          .first;

      final api = writeApiForComponent(
        function,
        result.temporaryDartFile.contents,
        export,
      );
      _overlayFs.setOverlay(
        file.apiDartPath,
        content: api,
        modificationStamp: now,
      );
    }

    file.state = ZapFileState.importsKnown;
  }

  Future<void> _resolve(ZapFile file) async {
    final dartContext = file.context!.dartContext;
    final dartResolver = _RawResolver(dartContext);

    final library = await dartResolver.resolveUri(
      Uri.file(file.temporaryDartPath),
    );
    dartResolver.referenceLibrary = library;

    final unit = await dartContext.currentSession.getResolvedUnit(
      file.temporaryDartPath,
    );
    if (unit is! ResolvedUnitResult) {
      throw StateError('Could not resolve unit for $file');
    }

    final errorReporter = _reportErrorsInFile(file);
    final prepareResult = file.prepareResult!;
    final resolver = Resolver(
      prepareResult,
      library,
      unit.unit,
      errorReporter,
      'ZapComponent',
    );
    final component = await resolver.resolve(dartResolver);

    // Also map Dart analysis errors back to the zap structures that were
    // mapped to the intermediate Dart file.
    MapDartErrorsInZapFile(
      file.prepareResult!,
      component,
      errorReporter,
    ).reportErrors(unit.errors);

    file.state = ZapFileState.analyzed;
    _finishedAnalysis.add(file);
  }

  ErrorReporter _reportErrorsInFile(ZapFile file) {
    return ErrorReporter(file.errors.add);
  }
}

class _RawResolver extends DartResolver {
  final AnalysisContext _originatingContext;
  LibraryElement2? referenceLibrary;

  _RawResolver(this._originatingContext);

  @override
  Future<LibraryElement2> get packageWeb async {
    if (referenceLibrary == null) {
      throw StateError(
        'Cannot resolve `package:web/web.dart` without a reference library',
      );
    }

    // Start crawling imports from the reference library
    final seen = <LibraryElement2>{referenceLibrary!};
    final toVisit = <LibraryElement2>[referenceLibrary!];

    while (toVisit.isNotEmpty) {
      final current = toVisit.removeLast();

      if (current.name3!.contains('dart.') && current.name3!.contains('html')) {
        return current;
      }

      final toCrawl = current.firstFragment.libraryImports2
          .map((i) => i.importedLibrary2!)
          .followedBy(
            current.firstFragment.libraryExports2.map(
              (i) => i.exportedLibrary2!,
            ),
          )
          .where((l) => !seen.contains(l))
          .toSet();
      toVisit.addAll(toCrawl);
      seen.addAll(toCrawl);
    }

    throw StateError('Could not find `package:web/web.dart`.');
  }

  @override
  Future<LibraryElement2> resolveUri(Uri uri) async {
    final result = await _originatingContext.currentSession.getLibraryByUri(
      uri.toString(),
    );

    if (result is LibraryElementResult) {
      return result.element2;
    }

    throw StateError('Could not resolve $uri to a library: $result');
  }

  @override
  Future<Uri> uriForElement(Element2 element) async {
    return element.library2!.uri;
  }
}
