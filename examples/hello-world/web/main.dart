import 'dart:html';
import 'package:hello_world/iteration.zap.dart';

void main() {
  final out = querySelector('#output')!;
  iteration().create(out);
}
