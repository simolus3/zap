import 'package:recase/recase.dart';

String dartComponentName(String basenameWithoutExtension) {
  return ReCase(basenameWithoutExtension).pascalCase;
}
