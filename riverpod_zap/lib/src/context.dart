import 'package:riverpod/riverpod.dart';
import 'package:zap/zap.dart';

const _scopeKey = #zap.riverpod.scope;

extension RiverpodScope on ComponentOrPending {
  ProviderContainer? get container => context[_scopeKey] as ProviderContainer?;

  set container(ProviderContainer? value) {
    context[_scopeKey] = value;
  }
}
