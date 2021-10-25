import 'package:html/parser.dart';
// ignore: implementation_imports
import 'package:html/src/token.dart';

class ZapHtmlParser extends HtmlParser {
  ZapHtmlParser(String input, String sourceUri)
      : super(input, generateSpans: true, sourceUrl: sourceUri);

  late final _zapPhase = _ZapFragmentPhase(this);

  @override
  set phase(Phase phase) {
    // Hack to replace package:html's InBodyPhase with the zap-specific phase.
    if (phase is InBodyPhase) {
      super.phase = _zapPhase;
    } else {
      super.phase = phase;
    }
  }
}

class _ZapFragmentPhase extends InBodyPhase {
  _ZapFragmentPhase(HtmlParser parser) : super(parser);

  @override
  Token? startTagOther(StartTagToken token) {
    tree
      ..reconstructActiveFormattingElements()
      ..insertElement(token);

    // Support self-closing tags even for non-void elements (we want to support
    // self-closing tags for zap subcomponents).
    if (token.selfClosing) {
      tree.openElements.removeLast();
      token.selfClosingAcknowledged = true;
    }
  }
}
