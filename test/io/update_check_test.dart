import 'package:flutter_test/flutter_test.dart';
import 'package:paint/io/update_check.dart';

void main() {
  group('compareVersions', () {
    test('orders by each numeric component in turn', () {
      expect(compareVersions('0.2.0', '0.1.0'), greaterThan(0));
      expect(compareVersions('0.1.0', '0.2.0'), lessThan(0));
      expect(compareVersions('1.0.0', '0.99.99'), greaterThan(0));
      expect(compareVersions('0.1.10', '0.1.9'), greaterThan(0));
    });

    test('compares components numerically, not as text', () {
      // The bug this guards: '10' sorts before '9' as a string, so a string
      // comparison would report 0.1.10 as older and never offer the upgrade.
      expect(compareVersions('0.10.0', '0.9.0'), greaterThan(0));
    });

    test('a missing component counts as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.1', '1.2'), greaterThan(0));
    });

    test('a prerelease is older than the release it leads to', () {
      expect(compareVersions('0.2.0-rc.1', '0.2.0'), lessThan(0));
      expect(compareVersions('0.2.0', '0.2.0-rc.1'), greaterThan(0));
      expect(compareVersions('0.2.0-rc.1', '0.2.0-rc.2'), lessThan(0));
    });

    test('identical versions compare equal', () {
      expect(compareVersions('0.1.0', '0.1.0'), 0);
    });

    test('surrounding whitespace does not matter', () {
      expect(compareVersions(' 0.2.0 ', '0.2.0'), 0);
    });
  });

  group('isNewerVersion', () {
    test('is true only for a strictly greater version', () {
      expect(isNewerVersion('0.2.0', '0.1.0'), isTrue);
      expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(isNewerVersion('0.0.9', '0.1.0'), isFalse);
    });
  });

  group('latestVersionIn', () {
    const index = '''
Package: paint
Version: 0.1.0
Architecture: amd64
Filename: pool/main/p/paint/paint_0.1.0_amd64.deb

Package: paint
Version: 0.2.0
Architecture: amd64
Filename: pool/main/p/paint/paint_0.2.0_amd64.deb
''';

    test('returns the highest version across stanzas', () {
      // The pool keeps every published version and apt-ftparchive does not
      // order them, so taking the last stanza would be wrong.
      expect(latestVersionIn(index), '0.2.0');
    });

    test('ignores other packages in the same index', () {
      const mixed = '''
Package: something-else
Version: 9.9.9

Package: paint
Version: 0.1.0
''';
      expect(latestVersionIn(mixed), '0.1.0');
    });

    test('returns null when the package is absent', () {
      expect(latestVersionIn('Package: other\nVersion: 1.0.0\n'), isNull);
    });

    test('returns null for an empty or unrelated body', () {
      expect(latestVersionIn(''), isNull);
      expect(latestVersionIn('<html>404</html>'), isNull);
    });

    test('reads a final stanza with no trailing blank line', () {
      expect(latestVersionIn('Package: paint\nVersion: 0.3.0'), '0.3.0');
    });
  });

  group('UpdateCheck', () {
    UpdateCheck checkReturning(String body) =>
        UpdateCheck(fetch: (_) async => body);

    test('reports a newer published version', () async {
      final check = checkReturning('Package: paint\nVersion: 0.2.0\n');
      expect(await check.newerThan('0.1.0'), '0.2.0');
    });

    test('reports nothing when already current', () async {
      final check = checkReturning('Package: paint\nVersion: 0.1.0\n');
      expect(await check.newerThan('0.1.0'), isNull);
    });

    test('reports nothing when running ahead of the repository', () async {
      // A locally built or AppImage copy can be newer than what is published.
      final check = checkReturning('Package: paint\nVersion: 0.1.0\n');
      expect(await check.newerThan('0.9.0'), isNull);
    });

    test('a failed fetch is null rather than an exception', () async {
      final check = UpdateCheck(
        fetch: (_) async => throw const UpdateCheckFailure(),
      );
      expect(await check.latestPublished(), isNull);
      expect(await check.newerThan('0.1.0'), isNull);
    });

    test('requests the configured index url', () async {
      Uri? requested;
      final check = UpdateCheck(
        indexUrl: 'https://example.test/Packages',
        fetch: (url) async {
          requested = url;
          return 'Package: paint\nVersion: 0.5.0\n';
        },
      );
      await check.latestPublished();
      expect(requested, Uri.parse('https://example.test/Packages'));
    });
  });
}
