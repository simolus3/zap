import 'dart:html';
import 'package:hello_world/async.zap.dart';

void main() {
  final out = querySelector('#output')!;
  async().mountTo(out);
}
