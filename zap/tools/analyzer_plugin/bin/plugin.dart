import 'dart:convert';
import 'dart:isolate';

import 'package:zap_dev/internal/plugin.dart';
import 'package:web_socket_channel/io.dart';

const useDebuggingVariant = true;

void main(List<String> args, SendPort sendPort) {
  if (useDebuggingVariant) {
    _PluginProxy(sendPort).start();
  } else {
    startPlugin(sendPort);
  }
}

/// Used during development. When [useDebuggingVariant] is enabled and a zap
/// plugin is running with `dart run zap_dev/tool/debug_plugin.dart`, this
/// enables easily debugging the zap plugin because it doesn't run inside the
/// analyzer process.
class _PluginProxy {
  final SendPort sendToAnalysisServer;

  final ReceivePort _receive = ReceivePort();
  final IOWebSocketChannel _channel =
      IOWebSocketChannel.connect('ws://localhost:9999');

  _PluginProxy(this.sendToAnalysisServer);

  Future<void> start() async {
    sendToAnalysisServer.send(_receive.sendPort);

    _receive.listen((data) {
      // the server will send messages as maps, convert to json
      _channel.sink.add(json.encode(data));
    });

    _channel.stream.listen((data) {
      sendToAnalysisServer.send(json.decode(data as String));
    });
  }
}
