import 'package:web/web.dart';
import 'package:zap_docs/src/getting_started/app.zap.dart';

void main() {
  final target = document.querySelector('main')!;
  App().create(target);
}
