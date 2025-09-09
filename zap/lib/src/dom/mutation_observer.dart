import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart';

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

    final observer = MutationObserver(
      (JSArray<MutationRecord> mutations, MutationObserver observer) {
        final typedMutations = mutations.toDart;

        for (final listener in listeners) {
          typedMutations.forEach(listener.add);
        }
      }.toJS,
    );

    void addListener(MultiStreamController<MutationRecord> listener) {
      if (listeners.isEmpty) {
        final options = MutationObserverInit();

        if (childList != null) options.childList = childList;
        if (attributes != null) options.attributes = attributes;
        if (characterData != null) options.characterData = characterData;
        if (subtree != null) options.subtree = subtree;
        if (attributeOldValue != null) {
          options.attributeOldValue = attributeOldValue;
        }
        if (characterDataOldValue != null) {
          options.characterDataOldValue = characterDataOldValue;
        }
        if (attributeFilter != null) {
          options.attributeFilter = attributeFilter
              .map((filter) => filter.toJS)
              .toList()
              .toJS;
        }

        // Start listening
        observer.observe(this, options);
      }

      listeners.add(listener);
    }

    void removeListener(MultiStreamController<MutationRecord> listener) {
      listeners.remove(listener);

      if (listeners.isEmpty) {
        observer.disconnect();
      }
    }

    return Stream.multi((newListener) {
      addListener(newListener);

      newListener
        ..onResume = (() => addListener(newListener))
        ..onPause = (() => removeListener(newListener))
        ..onCancel = (() => removeListener(newListener));
    }, isBroadcast: true);
  }
}

extension ObserveElementMutations on Element {
  /// Returns a stream of the attribute named [key] of this node.
  ///
  /// The stream will start with the current value of the attribute.
  Stream<String?> watchAttribute(String key) {
    return Stream.multi((listener) {
      listener.add((attributes[key] as JSString?)?.toDart);

      final changedValues = observeMutations(
        attributes: true,
        attributeFilter: [key],
      ).map((_) => (attributes[key] as JSString?)?.toDart);
      listener.addStream(changedValues);
    }, isBroadcast: true);
  }
}
