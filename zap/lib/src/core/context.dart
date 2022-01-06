import 'dart:collection';

class ContextScope extends MapBase<Object?, Object?> {
  final Map<Object?, Object?> definedData = {};
  final ContextScope? parent;

  ContextScope([this.parent]);

  @override
  Object? operator [](Object? key) {
    if (definedData.containsKey(key)) {
      return definedData[key];
    } else {
      return parent?[key];
    }
  }

  @override
  void operator []=(Object? key, Object? value) {
    definedData[key] = value;
  }

  @override
  void clear() {
    definedData.clear();
  }

  @override
  Iterable<Object?> get keys {
    final parent = this.parent;
    if (parent != null) {
      return parent.keys.followedBy(definedData.keys);
    } else {
      return definedData.keys;
    }
  }

  @override
  Object? remove(Object? key) {
    definedData.remove(key);
  }
}
