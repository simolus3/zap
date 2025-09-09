import '../component.dart';
import '../reactive_dom.dart';

class Optimizer {
  final ComponentOrSubcomponent component;

  Optimizer(this.component);

  OptimizationResults optimize() {
    final results = OptimizationResults();
    _visitComponent(component, results);
    return results;
  }

  void _visitComponent(
    ComponentOrSubcomponent component,
    OptimizationResults results,
  ) {
    if (component.children.isNotEmpty) {
      for (final child in component.children) {
        _visitComponent(child, results);
      }

      // We only optimize leaf components at the moment.
      return;
    }

    _visitFragment(component.fragment, results);

    // Component can be replaced with constant HTML if its content can and if
    // it's not using any updates expressed through flows.

    final result = results.forFragment(component.fragment);
    if (result.isCompileTimeConstant && component.flows.isEmpty) {
      results.forComponent(component).isCompileTimeConstant = true;
    }
  }

  void _visitFragment(DomFragment fragment, OptimizationResults results) {
    for (final node in fragment.rootNodes) {
      _visitNode(node, results);

      if (!results.forNode(node).isCompileTimeConstant) {
        results.forFragment(fragment).isCompileTimeConstant = false;
        break;
      }
    }
  }

  void _visitNode(ReactiveNode node, OptimizationResults results) {
    void notAConstant() {
      results.forNode(node).isCompileTimeConstant = false;
    }

    // We only consider text to be constant at the moment, this can be expanded
    // in the future.
    if (node is! ConstantText) {
      notAConstant();
    }

    for (final child in node.children) {
      _visitNode(child, results);

      if (!results.forNode(child).isCompileTimeConstant) {
        notAConstant();
      }
    }
  }
}

class OptimizationResults {
  final Map<ReactiveNode, NodeOptimization> nodes = {};
  final Map<DomFragment, NodeOptimization> fragments = {};
  final Map<ComponentOrSubcomponent, SubComponentOptimization> components = {};

  NodeOptimization forNode(ReactiveNode node) {
    return nodes.putIfAbsent(node, () => NodeOptimization());
  }

  NodeOptimization forFragment(DomFragment fragment) {
    return fragments.putIfAbsent(fragment, () => NodeOptimization());
  }

  SubComponentOptimization forComponent(ComponentOrSubcomponent component) {
    return components.putIfAbsent(component, () => SubComponentOptimization());
  }
}

class NodeOptimization {
  /// Whether this node is a compile-time constant, meaning that it does not
  /// depend on component state in any way.
  ///
  /// These nodes are interesting as we can just inline their HTML into
  /// generated code instead of generating individual nodes.
  bool isCompileTimeConstant = true;
}

class SubComponentOptimization {
  /// Whether this component is compile-time constant.
  ///
  /// Components are compile-time constant if their content is, and they don't
  /// have any flow actions to run.
  bool isCompileTimeConstant = false;
}
