import 'dart:io';

const packages = [
  'docs',
  'riverpod_zap',
  'riverpod_zap/example',
  'zap',
  'zap_dev',
];

void main() async {
  final failures = <String>[];

  for (final package in packages) {
    print('Running `dart pub upgrade` in $package');
    final process = await Process.start(
      'dart',
      ['pub', 'upgrade'],
      mode: ProcessStartMode.inheritStdio,
      workingDirectory: package,
    );

    final code = await process.exitCode;
    if (code != 0) {
      failures.add(package);
    }
  }

  if (failures.isNotEmpty) {
    print('Could not get dependencies in ${failures.join(', ')}');
    exit(1);
  }
}
