import 'dart:html';
import 'package:hello_world/hello_world.zap.dart';

void main() {
  final out = querySelector('#output')!;
  hello_world().mountTo(out);
}
