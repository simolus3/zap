import 'dart:io';

import 'package:simons_pub_uploader/upload.dart';

Future<void> main(List<String> args) async {
  final packages = <Package>[];

  for (final arg in args) {
    switch (arg) {
      case 'zap':
        packages.add(await FileSystemPackage.load(directory: 'zap'));
        break;
      case 'zap_dev':
        packages.add(await FileSystemPackage.load(
          directory: 'zap_dev',
          listPackageFiles: (fs) async* {
            final pkgDir = fs.directory('zap_dev');

            yield* pkgDir.childDirectory('lib').list(recursive: true);
            yield pkgDir.childFile('build.yaml');
          },
        ));
        break;
      case 'riverpod_zap':
        packages.add(await FileSystemPackage.load(directory: 'riverpod_zap'));
        break;
      default:
        print('Unknown package `$arg`');
    }
  }

  if (packages.isEmpty) {
    print('No packages found to upload.');
    exit(1);
  }

  print('Uploading ${packages.map((e) => e.name).join(' and ')}');
  await uploadPackages(packages);
}
