import 'package:args/command_runner.dart';

import 'commands/analyze.dart';

Future<void> runCli(List<String> args) async {
  final runner =
      CommandRunner('zap_dev', 'Utilities for working with `zap` packages.')
        ..addCommand(AnalyzeCommand());

  await runner.run(args);
}
