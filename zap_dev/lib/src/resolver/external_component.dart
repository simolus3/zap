import 'package:analyzer/dart/element/type.dart';

class ExternalComponent {
  final String className;
  final List<MapEntry<String, DartType>> parameters;

  ExternalComponent(this.className, this.parameters);
}
