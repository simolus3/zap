import 'dart:html';

import 'package:example/src/app.zap.dart';

void main() {
  final main = document.querySelector('main.container')!;

  App().create(main);
}
