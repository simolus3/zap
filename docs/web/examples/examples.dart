import 'package:web/web.dart';
import 'package:zap_docs/src/examples/scaffold/app.zap.dart';

void main() {
  final target = document.querySelector('main.container-fluid')!;

  while (target.firstChild != null) {
    target.removeChild(target.firstChild!);
  }

  App().create(target);
}
