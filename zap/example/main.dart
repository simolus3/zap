// zap_dev will create .zap.dart files for each .zap component.
import 'package:web/web.dart';

import 'counter.zap.dart';

void main() {
  // Create a component and mount it into the document of a webpage.
  Counter().create(document.body!);
}
