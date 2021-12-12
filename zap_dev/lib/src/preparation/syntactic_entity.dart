import 'package:source_span/source_span.dart';

abstract class SyntacticEntity {
  FileSpan get span;
}

class ParsingException implements Exception {}
