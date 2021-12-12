import 'dart:io';

Future<void> main() async {
  final proc = await Process.start(
    Platform.executable,
    [
      'run',
      'charcode',
      '-o',
      'lib/src/preparation/charcodes.g.dart',
      ' \t\r\n&;<>{:}/azAZ09="\'#,|_'
    ],
    mode: ProcessStartMode.inheritStdio,
  );
  await proc.exitCode;
}
