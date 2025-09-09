import 'dart:math';

abstract class GenerationNode {
  void renderInto(StringBuffer buffer);

  String render() {
    final buffer = StringBuffer();
    renderInto(buffer);
    return buffer.toString();
  }
}

enum ScopeLevel { library, $class, member }

class GenerationScope extends GenerationNode {
  final ScopeLevel level;
  final List<GenerationNode> children = [];

  GenerationScope([this.level = ScopeLevel.library]);

  StringBuffer leaf() {
    final leaf = Leaf();
    children.add(leaf);
    return leaf.buffer;
  }

  GenerationScope inner([ScopeLevel? level]) {
    level ??= ScopeLevel
        .values[max(this.level.index + 1, ScopeLevel.values.length - 1)];
    final inner = GenerationScope(level);
    children.add(inner);

    return inner;
  }

  @override
  void renderInto(StringBuffer buffer) {
    for (final child in children) {
      child.renderInto(buffer);
    }
  }
}

class Leaf extends GenerationNode {
  final StringBuffer buffer = StringBuffer();

  Leaf();

  @override
  void renderInto(StringBuffer buffer) {
    buffer.write(this.buffer);
  }
}
