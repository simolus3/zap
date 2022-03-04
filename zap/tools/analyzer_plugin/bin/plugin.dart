import 'dart:isolate';

import 'package:zap_dev/internal/plugin.dart';

void main(List<String> args, SendPort sendPort) {
  startPlugin(sendPort);
}
