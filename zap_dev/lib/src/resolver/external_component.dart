import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

class ExternalComponent {
  final ClassElement temporaryApiClass;
  final String tagName;
  final List<MapEntry<String, DartType>> parameters;
  final List<String?> slotNames;

  ExternalComponent(
    this.temporaryApiClass,
    this.tagName,
    this.parameters,
    this.slotNames,
  );
}
