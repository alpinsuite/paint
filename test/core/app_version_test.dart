import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paint/core/app_version.dart';

/// The version in `pubspec.yaml`, which is the canonical one.
String pubspecVersion() {
  final line = File(
    'pubspec.yaml',
  ).readAsLinesSync().firstWhere((line) => line.startsWith('version:'));
  // `version: 1.2.3+4` — the build number is not part of the release version.
  return line.split(':')[1].trim().split('+').first;
}

void main() {
  test('appVersion matches pubspec', () {
    // These drift silently, and the consequence is not cosmetic: the update
    // check compares appVersion against what the repository publishes, so a
    // build that understates its own version tells every user an upgrade is
    // waiting and never stops. `tools/set_version.sh` sets both; this is what
    // notices when someone edits pubspec by hand.
    expect(
      appVersion,
      pubspecVersion(),
      reason:
          'lib/core/app_version.dart is out of step with pubspec.yaml. '
          'Run tools/set_version.sh <version> rather than editing either.',
    );
  });

  test('appVersion looks like a version', () {
    expect(appVersion, matches(RegExp(r'^\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$')));
  });
}
