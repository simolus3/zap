import 'package:build/build.dart';
import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart' as css;
import 'package:glob/glob.dart';
import 'package:path/path.dart';

class AggregateCss implements Builder {
  final String output;

  AggregateCss(this.output);

  @override
  Future<void> build(BuildStep buildStep) async {
    final output = buildStep.allowedOutputs.single;
    final printer = css.CssPrinter();

    final glob = Glob('**/*.zap', context: url);
    final seenFiles = <AssetId>{};
    final pending = <AssetId>[];

    // Find roots
    await for (final asset in buildStep
        .findAssets(glob)
        .map((e) => e.changeExtension('.tmp.zap.css'))) {
      if (seenFiles.add(asset)) {
        pending.add(asset);
      }
    }

    // Then BFS through imports
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      String content;

      try {
        content = await buildStep.readAsString(id);
      } on AssetNotFoundException {
        continue;
      }

      final stylesheet = css.parse(content);

      for (final node in stylesheet.topLevels) {
        // Resolve includes, write other nodes
        if (node is css.IncludeDirective) {
          final imported = AssetId.resolve(Uri.parse(node.name), from: id);

          if (seenFiles.add(imported)) {
            pending.add(imported);
          }
        } else {
          node.visit(printer);
        }
      }
    }

    await buildStep.writeAsString(output, printer.toString());
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        r'lib/$lib$': ['web/main.css'],
      };
}
