import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;

import '../../version.dart';
import '../context.dart';
import '../worker.dart';

class DriftAnalyzerPlugin extends ServerPlugin {
  late final ZapWorker _worker = ZapWorker(resourceProvider);
  final Map<plugin.ContextRoot, ZapAnalysisContext> _contexts = {};

  DriftAnalyzerPlugin(ResourceProvider? provider) : super(provider);

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
  void contentChanged(String path) {}

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
}
