import 'package:jaspr/jaspr.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

/// A jaspr component that parses [rawHtml] and inserts it into the document.
final class RawHtml extends StatefulComponent {
  final String rawHtml;

  const RawHtml(this.rawHtml, {super.key});

  @override
  State<StatefulComponent> createState() {
    return _RawHtmlState();
  }
}

final class _RawHtmlState extends State<RawHtml> {
  /// An artificial element that we never insert into the document.
  ///
  /// We call `innerHtml` on this element to obtain the nodes that need to be
  /// inserted into the actual document.
  final web.Element _artificialParent = web.HTMLDivElement();

  @override
  void didUpdateComponent(covariant RawHtml oldComponent) {
    _artificialParent.setHTMLUnsafe(component.rawHtml.toJS);
    super.didUpdateComponent(oldComponent);
  }

  @override
  Iterable<Component> build(BuildContext context) {
    return [RawNode(_artificialParent)];
  }
}
