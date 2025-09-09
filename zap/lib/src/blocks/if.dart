import 'package:web/web.dart';

import '../core/fragment.dart';

/// An if-else construct that selects between multiple components, or none.
class IfBlock extends Fragment {
  /// The function creating the subcomponent shown by this if statement.
  ///
  /// The function receives a number representing the branch taken in this
  /// if/else if/else chain and creates a component for that branch.
  /// This if block is responsible for delegating lifecycle methods to that
  /// component.
  final Fragment? Function(int) _create;

  /// An invisible node that we're inserting into the DOM as an anchor for a
  /// child component later.
  ///
  /// When changing the component rendered by this `if` block, we need to mount
  /// it at the correct location. The easiest way to do this is to insert a
  /// small text node at the location requested by [create] and then use that
  /// as an anchor for the child component.
  final Text _anchor = Text('');

  Fragment? _current;
  int _currentCaseNumber = -1;
  bool _isMounted = false;

  IfBlock(this._create);

  /// Notifies this if block that a different branch may have been taken, in
  /// which case the inner component will update.
  void reEvaluate(int caseNumber) {
    if (_currentCaseNumber != caseNumber) {
      _current?.destroy();
      _current = null;

      _currentCaseNumber = caseNumber;
      final newBlock = _current = _create(caseNumber);

      if (newBlock != null) {
        if (_isMounted) {
          newBlock.create(_anchor.parentElement!, _anchor);
        }
      }
    }
  }

  @override
  void create(Element target, [Node? anchor]) {
    target.insertBefore(_anchor, anchor);
    _current?.create(target, _anchor);
    _isMounted = true;
  }

  @override
  void update(int delta) {
    _current?.update(delta);
  }

  @override
  void destroy() {
    _current?.destroy();
    _anchor.remove();
  }
}
