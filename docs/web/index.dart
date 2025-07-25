import 'package:web/web.dart';
import 'package:zap_docs/src/demo/counter.zap.dart';

void main() {
  final target = document.getElementById('index-example-1')!;

  while (target.firstChild != null) {
    target.removeChild(target.firstChild!);
  }

  Counter().create(target);
}
