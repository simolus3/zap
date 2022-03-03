import 'dart:io';

import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../file.dart';
import '../../worker.dart';

class AnalyzeCommand extends Command {
  @override
  String get description =>
      'Analyze and lint zap files in the current directory.';

  @override
  String get name => 'analyze';

  @override
  Future<void> run() async {
    final worker = ZapWorker(PhysicalResourceProvider.INSTANCE);
    worker.newContext(Directory.current.absolute.path);

    var totalErrors = 0;

    await for (final file in Directory.current.list(recursive: true)) {
      if (file is File && p.extension(file.path) == '.zap') {
        final result = worker.file(file.absolute.path);
        await worker.analyze(result);

        if (result is ZapFile && result.errors.isNotEmpty) {
          for (final error in result.errors) {
            print(error.humanReadableDescription());
          }
        }
      }
    }

    if (totalErrors == 0) {
      print('No errors found');
    } else {
      print('$totalErrors errors found.');
    }
  }
}
