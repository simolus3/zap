import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:zap/zap.dart';

class ProviderWatchable<State> extends Stream<State>
    implements Watchable<State> {
  final ProviderContainer _container;
  final ProviderListenable<State> _provider;

  ProviderSubscription<State>? _currentSubscription;
  final List<MultiStreamController<State>> _listeners = [];
  int _streamListeners = 0;

  late Stream<State> _dartStream;

  ProviderWatchable(this._container, this._provider) {
    _dartStream = Stream.multi(
      (listener) {
        void startListening() {
          _listeners.add(listener);
          _newListener();
        }

        void stopListening() {
          if (_listeners.remove(listener)) {
            _listenerStopped();
          }
        }

        listener
          ..onResume = startListening
          ..onPause = stopListening
          ..onCancel = stopListening;
        startListening();
      },
      isBroadcast: true,
    );
  }

  ProviderSubscription<State> _newListener() {
    _streamListeners++;
    return _currentSubscription ??= _container.listen(
      _provider,
      (previous, next) {
        for (final listener in _listeners) {
          listener.add(next);
        }
      },
      onError: (error, stackTrace) {
        for (final listener in _listeners) {
          listener.addError(error, stackTrace);
        }
      },
    );
  }

  void _listenerStopped() {
    _streamListeners--;
    if (_streamListeners == 0) {
      _currentSubscription?.close();
      _currentSubscription = null;
    }
  }

  @override
  StreamSubscription<State> listen(void Function(State event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _dartStream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  State get value {
    // Create a short-lived subscription to read the state.
    final subscription = _newListener();
    final state = subscription.read();
    _listenerStopped();

    return state;
  }
}
