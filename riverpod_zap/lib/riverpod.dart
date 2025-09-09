// When this library is imported from a zap component, also make the
// riverpod-scope component available.
@pragma('zap:additional_export', ['src/riverpod-scope.zap'])
// ignore: unnecessary_library_name
library riverpod_zap;

import 'package:riverpod/riverpod.dart';
import 'package:zap/zap.dart';

import 'src/context.dart';
import 'src/watchable.dart';

extension RiverpodZap on ComponentOrPending {
  ProviderContainer get riverpodContainer => container!;

  T read<T>(ProviderListenable<T> provider) => riverpodContainer.read(provider);

  Watchable<State> use<State>(ProviderListenable<State> provider) {
    return ProviderWatchable(riverpodContainer, provider);
  }
}
