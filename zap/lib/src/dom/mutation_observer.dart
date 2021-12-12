import 'dart:async';
import 'dart:html';

extension ObserveMutations on Node {
  Stream<MutationRecord> observeMutations({
    bool? childList,
    bool? attributes,
    bool? characterData,
    bool? subtree,
    bool? attributeOldValue,
    bool? characterDataOldValue,
    List<String>? attributeFilter,
  }) {
    final listeners = <MultiStreamController<MutationRecord>>[];

    final observer = MutationObserver((mutations, observer) {
      final typedMutations = mutations.cast<MutationRecord>();

      for (final listener in listeners) {
        typedMutations.forEach(listener.add);
      }
    });

    void addListener(MultiStreamController<MutationRecord> listener) {
      if (listeners.isEmpty) {
        // Start listening
        observer.observe(
          this,
          childList: childList,
          attributes: attributes,
          characterData: characterData,
          subtree: subtree,
          attributeOldValue: attributeOldValue,
          characterDataOldValue: characterDataOldValue,
          attributeFilter: attributeFilter,
        );
      }

      listeners.add(listener);
    }

    void removeListener(MultiStreamController<MutationRecord> listener) {
      listeners.remove(listener);

      if (listeners.isEmpty) {
        observer.disconnect();
      }
    }

    return Stream.multi(
      (newListener) {
        addListener(newListener);

        newListener
          ..onResume = (() => addListener(newListener))
          ..onPause = (() => removeListener(newListener))
          ..onCancel = (() => removeListener(newListener));
      },
      isBroadcast: true,
    );
  }
}

extension ObserveElementMutations on Element {
  /// Returns a stream of the attribute named [key] of this node.
  ///
  /// The stream will start with the current value of the attribute.
  Stream<String?> watchAttribute(String key) {
    return Stream.multi(
      (listener) {
        listener.add(attributes[key]);

        final changedValues = observeMutations(
          attributes: true,
          attributeFilter: [key],
        ).map((_) => attributes[key]);
        listener.addStream(changedValues);
      },
      isBroadcast: true,
    );
  }
}
