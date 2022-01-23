library riverpod_zap;

import 'package:riverpod/riverpod.dart';
import 'package:zap/zap.dart';

import 'src/context.dart';
import 'src/watchable.dart';

extension RiverpodZap on ComponentOrPending {
  ProviderContainer get riverpodContainer => container!;

  T read<T>(ProviderBase<T> provider) => riverpodContainer.read(provider);

  Watchable<State> use<State>(ProviderListenable<State> provider) {
    return ProviderWatchable(riverpodContainer, provider);
  }
}
