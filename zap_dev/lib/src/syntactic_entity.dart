import 'package:source_span/source_span.dart';

abstract class SyntacticEntity {
  /// The piece of text forming this syntactic entity.
  FileSpan get span;

  /// The first position of this entity, as an zero-based offset in the file it
  /// was read from.
  ///
  /// Instead of returning null, this getter may throw for entities where
  /// [hasSpan] is false.
  int get firstPosition => span.start.offset;

  /// The (exclusive) last index of this entity in the source.
  ///
  /// Instead of returning null, this getter may throw for entities where
  /// [hasSpan] is false.
  int get lastPosition => span.end.offset;

  /// The length of this syntactic entities, in codepoints.
  int get length => span.length;
}
