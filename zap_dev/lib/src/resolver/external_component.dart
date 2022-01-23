import 'package:analyzer/dart/element/type.dart';

class ExternalComponent {
  final String className;
  final String tagName;
  final List<MapEntry<String, DartType>> parameters;
  final List<String?> slotNames;

  ExternalComponent(
      this.className, this.tagName, this.parameters, this.slotNames);
}
