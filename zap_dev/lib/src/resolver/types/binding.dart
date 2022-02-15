import 'package:zap_dev/src/errors.dart';

import '../../preparation/ast.dart' as prep;
import '../dart.dart';
import '../external_component.dart';
import '../reactive_dom.dart';
import 'checker.dart';

extension CheckBindings on TypeChecker {
  ElementBinder checkBindProperty({
    required String bindName,
    required String elementTagName,
    required DartCodeVariable targetVariable,
    required prep.Attribute attribute,
    ExternalComponent? external,
  }) {
    if (bindName == 'this') {
      // todo: Type checking for external components is a bit complicated since
      // it isn't generated at the time we run the check.
      if (external == null) {
        final type =
            domTypes.dartTypeForElement(elementTagName) ?? domTypes.element;

        if (!typeSystem.isAssignableTo(type, targetVariable.type)) {
          errors.reportError(ZapError.onNode(
            attribute,
            'Target of `this` binding must be of type '
            '${type.getDisplayString(withNullability: true)}',
          ));
        }

        return BindThis(targetVariable);
      }
    }

    SpecialBindingMode? specialMode;

    if (elementTagName == 'input') {
      switch (bindName) {
        case 'value':
          specialMode = SpecialBindingMode.inputValue;
          if (!isNullableString(targetVariable.type)) {
            errors.reportError(
                ZapError.onNode(attribute, 'Must be a string variable'));
          }
          break;
      }
    }

    return BindProperty(bindName, targetVariable, specialMode: specialMode);
  }
}
