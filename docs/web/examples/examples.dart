import 'dart:html';

import 'package:zap_docs/src/examples/scaffold/app.zap.dart';

void main() {
  final target = document.querySelector('main.container-fluid')!;
  target.children.clear();
  App().create(target);
}
