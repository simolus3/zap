import 'dart:isolate';

import 'package:analyzer_plugin/starter.dart';

import '../src/standalone/plugin/plugin.dart';

void startPlugin(SendPort sendPort) {
  ServerPluginStarter(ZapPlugin()).start(sendPort);
}
