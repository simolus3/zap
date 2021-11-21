import 'dart:html';

import 'package:seven_guis/selector.zap.dart';

void main() {
  final app = selector();
  app.mountTo(querySelector('#output')!);
}
