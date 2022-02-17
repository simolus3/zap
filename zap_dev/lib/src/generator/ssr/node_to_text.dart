import '../../resolver/reactive_dom.dart';

class NodeWriter {
  final StringBuffer buffer = StringBuffer();

  void writeNode(ReactiveNode node) {
    if (node is ConstantText) {
      buffer.write(node.text);
    }

    // Other nodes are not currently supported.
    node.children.forEach(writeNode);
  }
}
