import 'dart:html';

/// A zap-managed fragment in the DOM tree with lifecycle callbacks.
abstract class Fragment {
  /// Synchronously creates nodes in this fragment without inserting them into
  /// the document.
  ///
  /// This method may only be called once.
  void create();

  /// Synchronously inserts the nodes created with [create] into the document.
  ///
  /// The [target] is used as a parent node, and the optional [anchor] can be
  /// used to insert this fragment after an existing child. When absent, this
  /// fragment will be inserted at the end of [target].
  ///
  /// This method may only be called once, and only after calling [create].
  void mount(Element target, [Node? anchor]);

  /// Synchronously applies updates to the DOM subtree managed by this fragment.
  ///
  /// The [delta] parameter is implementation-specific and can be used to
  /// denote which parts of the fragment's state have changed for more efficient
  /// updates.
  void update(int delta);

  /// Synchronously removes nodes managed by this component from the document.
  ///
  /// This method may only be called once.
  void destroy();
}
