import 'dart:typed_data';

import 'package:analyzer/file_system/file_system.dart';
import 'package:path/path.dart';

/// The build system generates hidden assets into `.dart_tool/build/generated`,
/// but these assets can be imported as if they were located right in the
/// project's source tree.
///
/// The analyzer tries to be smart about this by rewiring file lookups to also
/// find files in `.dart_tool/build/generated`. This is pretty neat overall, but
/// the exact opposite of what we want when we control the intermediate zap
/// files with an overlay file system.
/// To disable this mechanism, we hide the generated folder from the analyzer.
class HideGeneratedBuildFolder extends ResourceProvider {
  final ResourceProvider _inner;

  HideGeneratedBuildFolder(this._inner);

  @override
  Link getLink(String path) {
    throw UnimplementedError();
  }

  @override
  File getFile(String path) {
    return _HideGeneratedBuildFile(_inner.getFile(path), this);
  }

  @override
  Folder getFolder(String path) {
    return _HideGeneratedBuildFolder(_inner.getFolder(path), this);
  }

  @override
  Resource getResource(String path) {
    return _HideGeneratedBuildResource.wrap(this, _inner.getResource(path));
  }

  @override
  Folder? getStateLocation(String pluginId) {
    final inner = _inner.getStateLocation(pluginId);

    if (inner != null) {
      return _HideGeneratedBuildFolder(inner, this);
    }
  }

  @override
  Context get pathContext => _inner.pathContext;
}

abstract class _HideGeneratedBuildResource extends Resource {
  final Resource _inner;
  final HideGeneratedBuildFolder _provider;

  _HideGeneratedBuildResource(this._inner, this._provider);

  factory _HideGeneratedBuildResource.wrap(
    HideGeneratedBuildFolder provider,
    Resource inner,
  ) {
    if (inner is File) {
      return _HideGeneratedBuildFile(inner, provider);
    } else if (inner is Folder) {
      return _HideGeneratedBuildFolder(inner, provider);
    } else {
      throw AssertionError('Should be file or folder');
    }
  }

  @override
  Resource copyTo(Folder parentFolder) => _inner.copyTo(parentFolder);

  @override
  void delete() => _inner.delete();

  @override
  bool get exists {
    if (!_inner.exists) return false;

    // Hide this entity if it's somewhere in `.dart_tool/build`.
    final pathComponents = _provider.pathContext.split(path);
    final dartToolIdx = pathComponents.indexOf('.dart_tool');
    if (dartToolIdx < 0 || dartToolIdx >= pathComponents.length - 1) {
      return true;
    }

    return pathComponents[dartToolIdx + 1] != 'build';
  }

  @override
  bool isOrContains(String path) => _inner.isOrContains(path);

  @override
  Folder get parent => _HideGeneratedBuildFolder(_inner.parent, _provider);

  @override
  String get path => _inner.path;

  @override
  ResourceProvider get provider => _provider;

  @override
  Resource resolveSymbolicLinksSync() => _HideGeneratedBuildResource.wrap(
    _provider,
    _inner.resolveSymbolicLinksSync(),
  );

  @override
  String get shortName => _inner.shortName;

  @override
  Uri toUri() => _inner.toUri();

  @override
  ResourceWatcher watch() => _inner.watch();
}

class _HideGeneratedBuildFolder extends _HideGeneratedBuildResource
    implements Folder {
  @override
  Folder get _inner => super._inner as Folder;

  _HideGeneratedBuildFolder(super.inner, super.provider);

  @override
  Folder copyTo(Folder parentFolder) {
    return _HideGeneratedBuildFolder(_inner.copyTo(parentFolder), _provider);
  }

  @override
  String canonicalizePath(String path) => _inner.canonicalizePath(path);

  @override
  bool contains(String path) => _inner.contains(path);

  @override
  void create() => _inner.create();

  @override
  Resource getChild(String relPath) =>
      _HideGeneratedBuildResource.wrap(_provider, _inner.getChild(relPath));

  @override
  File getChildAssumingFile(String relPath) {
    return _HideGeneratedBuildFile(
      _inner.getChildAssumingFile(relPath),
      _provider,
    );
  }

  @override
  Folder getChildAssumingFolder(String relPath) {
    return _HideGeneratedBuildFolder(
      _inner.getChildAssumingFolder(relPath),
      _provider,
    );
  }

  @override
  List<Resource> getChildren() {
    return [
      for (final child in _inner.getChildren())
        _HideGeneratedBuildResource.wrap(_provider, child),
    ];
  }

  @override
  bool get isRoot => _inner.isRoot;
}

class _HideGeneratedBuildFile extends _HideGeneratedBuildResource
    implements File {
  @override
  File get _inner => super._inner as File;

  _HideGeneratedBuildFile(File super.inner, super.provider);

  @override
  File copyTo(Folder parentFolder) {
    return _HideGeneratedBuildFile(_inner.copyTo(parentFolder), _provider);
  }

  @override
  int get lengthSync => _inner.lengthSync;

  @override
  int get modificationStamp => _inner.modificationStamp;

  @override
  Uint8List readAsBytesSync() => _inner.readAsBytesSync();

  @override
  String readAsStringSync() => _inner.readAsStringSync();

  @override
  File renameSync(String newPath) {
    return _HideGeneratedBuildFile(_inner.renameSync(newPath), _provider);
  }

  @override
  void writeAsBytesSync(List<int> bytes) => _inner.writeAsBytesSync(bytes);

  @override
  void writeAsStringSync(String content) => _inner.writeAsStringSync(content);
}
