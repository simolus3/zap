/// Definitions inspected at build-time. These only exists so that they can
/// be recognized by the zap compiler.
library zap.internal.dsl;

import 'dart:async';

import '../src/core/snapshot.dart';
import '../src/core/watchable.dart';

export 'package:zap/zap.dart'
    show ComponentOrPending, EmitCustomEvent, ZapSnapshot;

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

ZapSnapshot<T> extractFromFuture<T>(FutureOr<T> future) {
  throw UnsupportedError('Only used statically to mess with the type system.');
}

ZapSnapshot<T> extractFromStream<T>(Stream<T> stream) {
  throw UnsupportedError('Only used statically to mess with the type system.');
}
