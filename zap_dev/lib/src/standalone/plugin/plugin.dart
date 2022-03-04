import 'dart:async';

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:source_span/source_span.dart';

import '../../version.dart';
import '../context.dart';
import '../file.dart';
import '../worker.dart';

class ZapPlugin extends ServerPlugin {
  late final ZapWorker _worker = ZapWorker(resourceProvider);
  final Map<plugin.ContextRoot, ZapAnalysisContext> _contexts = {};

  StreamSubscription? _workerSubscription;

  ZapPlugin([ResourceProvider? provider]) : super(provider) {
    _workerSubscription = _worker.analyzedFiles.listen(sendErrorsNotification);
  }

  @override
  List<String> get fileGlobsToAnalyze => ['*.zap'];

  @override
  String get name => 'zap';

  @override
  String get version => packageVersion;

  @override
  String? get contactInfo => 'https://github.com/simolus3/zap/issues/new';

  @override
  Never createAnalysisDriver(contextRoot) {
    // analysis drivers are an outdated API, but the plugin interface wants us
    // to provide this method. We manually keep track of newer analysis contexts
    // instead, those are much easier to use.
    throw UnsupportedError('not used');
  }

  @override
  Future<plugin.PluginShutdownResult> handlePluginShutdown(
      plugin.PluginShutdownParams parameters) async {
    await _workerSubscription?.cancel();
    return plugin.PluginShutdownResult();
  }

  @override
  void contentChanged(String path) {
    final file = _worker.file(path);
    if (file is ZapFile) {
      file.state = ZapFileState.dirty;

      // Schedule for an analysis round.
      _worker.analyze(file);
    }
  }

  @override
  bool isCompatibleWith(serverVersion) => true;

  @override
  Future<plugin.AnalysisSetContextRootsResult> handleAnalysisSetContextRoots(
      plugin.AnalysisSetContextRootsParams parameters) {
    final roots = parameters.roots;
    final oldRoots = _contexts.keys.toList();

    for (final contextRoot in roots) {
      if (!oldRoots.remove(contextRoot)) {
        // The context is new! Register it to the worker.
        final context =
            _worker.newContext(contextRoot.root, contextRoot.exclude);
        _contexts[contextRoot] = context;
      }
    }

    // All remaining contexts have been removed
    for (final removed in oldRoots) {
      _worker.closeContext(_contexts.remove(removed)!);
    }

    return Future.value(plugin.AnalysisSetContextRootsResult());
  }

  plugin.Location _location(RegisteredFile file, SourceSpan span) {
    final start = span.start;
    final end = span.end;

    return plugin.Location(
      file.file.path,
      start.offset,
      span.length,
      start.line + 1,
      start.column + 1,
      endLine: end.line + 1,
      endColumn: end.column + 1,
    );
  }

  void sendErrorsNotification(ZapFile file) {
    channel.sendNotification(plugin.AnalysisErrorsParams(
      file.file.path,
      [
        for (final error in file.errors)
          plugin.AnalysisError(
            plugin.AnalysisErrorSeverity.ERROR,
            plugin.AnalysisErrorType.COMPILE_TIME_ERROR,
            _location(
              file,
              error.span ??
                  SourceSpan(SourceLocation(0), SourceLocation(0), ''),
            ),
            error.message,
            'zap',
          ),
      ],
    ).toNotification());
  }
}
