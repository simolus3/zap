import 'dart:html';

import 'package:zap_docs/src/demo/counter.zap.dart';

void main() {
  final target = document.getElementById('index-example-1')!;

  target.children.clear();
  Counter().create(target);
}
