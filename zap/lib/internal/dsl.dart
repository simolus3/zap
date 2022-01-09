/// Definitions inspected at build-time. These only exists so that they can
/// be recognized by the zap compiler.
library zap.internal.dsl;

import '../src/core/watchable.dart';

export 'package:zap/zap.dart' show ComponentOrPending, ZapSnapshot;

class Property {
  final String? key;

  const Property([this.key]);
}

const prop = Property();

class _ComponentMarker {
  const _ComponentMarker();
}

const $$componentMarker = _ComponentMarker();

class Slot {
  final String? name;

  const Slot(this.name);
}

T watch<T>(Watchable<T> watchable) {
  return watchable.value;
}
