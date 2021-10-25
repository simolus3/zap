import 'package:build/build.dart';

import '../errors.dart';

void reportError(ZapError error) {
  log.warning(error.humanReadableDescription());
}
