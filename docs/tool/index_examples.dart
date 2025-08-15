import 'dart:convert';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;

import 'package:zap_docs/src/examples/examples.dart';

class IndexExamples implements Builder {
  IndexExamples(BuilderOptions _);

  Map<String, List<String>> get buildExtensions {
    return const {
      r'lib/src/examples/examples.dart': ['web/examples/sources.json'],
    };
  }

  Future<void> build(BuildStep step) async {
    final sources = [
      for (final group in examples)
        for (final example in group.children)
          {
            'id': example.id,
            'files': [
              for (final file in example.files)
                {
                  'name': p.basename(file),
                  'contents': await step.readAsString(
                    AssetId.resolve(Uri.parse(file), from: step.inputId),
                  ),
                },
            ],
          },
    ];

    await step.writeAsString(step.allowedOutputs.single, json.encode(sources));
  }
}
