import 'package:example/src/app.zap.dart';
import 'package:web/web.dart';

void main() {
  final main = document.querySelector('main.container')!;

  App().create(main);
}
