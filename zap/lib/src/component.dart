import 'package:jaspr/ui.dart';

abstract base class ZapGeneratedState<C extends StatefulComponent>
    extends State<C> {
  T $invalidateAssign<T>(T expr) {
    setState(() {});
    return expr;
  }

  static String classAttribute(String scopedCssClass, String otherClasses) {
    return '$scopedCssClass $otherClasses';
  }
}

typedef Fragment = State<FragmentComponent>;

final class FragmentComponent extends StatefulComponent {
  final State<StatefulComponent> Function() _createState;

  FragmentComponent(this._createState, {super.key});

  @override
  State<StatefulComponent> createState() {
    return _createState();
  }
}
