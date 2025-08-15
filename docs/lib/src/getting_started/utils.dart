// Logic copied from https://github.com/dart-lang/linter/blob/master/lib/src/utils.dart
// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// An identifier here is defined as:
// * A sequence of `_`, `$`, letters or digits,
// * where no `$` comes after a digit.
final _identifier = RegExp(r'^[_$a-z]+(\d[_a-z\d]*)?$', caseSensitive: false);

// A lower-case underscored (snake-case) with leading underscores is defined as
// * An optional leading sequence of any number of underscores,
// * followed by a sequence of lower-case letters, digits and underscores,
// * with no two adjacent underscores,
// * and not ending in an underscore.
final _lowerCaseUnderScoreWithLeadingUnderscores = RegExp(
  r'^_*[a-z](?:_?[a-z\d])*$',
);

/// Returns `true` if this [name] is a legal Dart identifier.
bool isIdentifier(String name) => _identifier.hasMatch(name);

/// Returns true if this [id] is a valid package name.
bool isValidPackageName(String id) {
  return _lowerCaseUnderScoreWithLeadingUnderscores.hasMatch(id) &&
      isIdentifier(id) &&
      !forbiddenPackageNames.contains(id);
}

const forbiddenPackageNames = [...reservedWords, ...badPackageNames];

const reservedWords = [
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
];

const badPackageNames = ['zap', 'zap_dev', 'riverpod_zap'];
