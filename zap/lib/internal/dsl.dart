/// Definitions inspected at build-time. These only exists so that they can
/// be recognized by the zap compiler.
library;

import 'dart:async';

import 'package:jaspr/jaspr.dart';

import '../src/core/watchable.dart';

export 'package:jaspr/jaspr.dart' show AsyncSnapshot;

class Property {
  final String? key;

  const Property([this.key]);
}

const prop = Property();

class $ComponentMarker {
  final String tagName;

  const $ComponentMarker(this.tagName);
}

class Slot {
  final String? name;

  const Slot(this.name);
}

T watch<T>(Watchable<T> watchable) {
  return watchable.value;
}

T extractFromIterable<T>(Iterable<T> iterable) {
  throw UnsupportedError('Only used statically to mess with the type system.');
}

AsyncSnapshot<T> extractFromFuture<T>(FutureOr<T> future) {
  throw UnsupportedError('Only used statically to mess with the type system.');
}

AsyncSnapshot<T> extractFromStream<T>(Stream<T> stream) {
  throw UnsupportedError('Only used statically to mess with the type system.');
}
