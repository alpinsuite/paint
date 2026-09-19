import 'package:flutter_test/flutter_test.dart';
import 'package:paint/controller/update_controller.dart';
import 'package:paint/core/settings/settings_controller.dart';
import 'package:paint/io/update_check.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsController> settingsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsController.load();
}

UpdateCheck publishing(String version) =>
    UpdateCheck(fetch: (_) async => 'Package: paint\nVersion: $version\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateController.checkIfDue', () {
    test('does nothing when the user has not enabled checks', () async {
      var fetched = false;
      final controller = UpdateController(
        settings: await settingsWith(<String, Object>{}),
        currentVersion: '0.1.0',
        check: UpdateCheck(
          fetch: (_) async {
            fetched = true;
            return 'Package: paint\nVersion: 9.9.9\n';
          },
        ),
      );

      await controller.checkIfDue();

      // The point of the setting: no socket is opened until it is turned on.
      expect(fetched, isFalse);
      expect(controller.availableVersion, isNull);
    });

    test('reports a newer version once enabled', () async {
      final controller = UpdateController(
        settings: await settingsWith(<String, Object>{
          'flutter.update_check_enabled': true,
        }),
        currentVersion: '0.1.0',
        check: publishing('0.2.0'),
      );

      await controller.checkIfDue();

      expect(controller.availableVersion, '0.2.0');
    });

    test('stays quiet when the published version is the current one', () async {
      final controller = UpdateController(
        settings: await settingsWith(<String, Object>{
          'flutter.update_check_enabled': true,
        }),
        currentVersion: '0.2.0',
        check: publishing('0.2.0'),
      );

      await controller.checkIfDue();

      expect(controller.availableVersion, isNull);
    });

    test('does not check again within the interval', () async {
      final now = DateTime(2026, 8, 7, 12);
      var fetches = 0;
      final controller = UpdateController(
        settings: await settingsWith(<String, Object>{
          'flutter.update_check_enabled': true,
          'flutter.last_update_check': now
              .subtract(const Duration(hours: 3))
              .millisecondsSinceEpoch,
        }),
        currentVersion: '0.1.0',
        check: UpdateCheck(
          fetch: (_) async {
            fetches++;
            return 'Package: paint\nVersion: 0.2.0\n';
          },
        ),
      );

      await controller.checkIfDue(now: now);

      expect(fetches, 0);
    });

    test('checks again once the interval has passed', () async {
      final now = DateTime(2026, 8, 7, 12);
      final controller = UpdateController(
        settings: await settingsWith(<String, Object>{
          'flutter.update_check_enabled': true,
          'flutter.last_update_check': now
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch,
        }),
        currentVersion: '0.1.0',
        check: publishing('0.2.0'),
      );

      await controller.checkIfDue(now: now);

      expect(controller.availableVersion, '0.2.0');
    });

    test('records when the automatic check ran', () async {
      final now = DateTime(2026, 8, 7, 12);
      final settings = await settingsWith(<String, Object>{
        'flutter.update_check_enabled': true,
      });
      final controller = UpdateController(
        settings: settings,
        currentVersion: '0.1.0',
        check: publishing('0.2.0'),
      );

      await controller.checkIfDue(now: now);

      expect(settings.lastUpdateCheck, now);
    });
  });

  group('UpdateController.checkNow', () {
    test('runs even when automatic checks are off', () async {
      final controller = UpdateController(
        settings: await settingsWith(<String, Object>{}),
        currentVersion: '0.1.0',
        check: publishing('0.3.0'),
      );

      // Pressing the menu item is consent for that one check.
      expect(await controller.checkNow(), '0.3.0');
    });

    test('returns null when already current', () async {
      final controller = UpdateController(
        settings: await settingsWith(<String, Object>{}),
        currentVersion: '0.3.0',
        check: publishing('0.3.0'),
      );

      expect(await controller.checkNow(), isNull);
    });

    test('throws when the repository cannot be reached', () async {
      final controller = UpdateController(
        settings: await settingsWith(<String, Object>{}),
        currentVersion: '0.1.0',
        check: UpdateCheck(fetch: (_) async => throw Exception('offline')),
      );

      // Silence after pressing a button reads as "up to date", which would be
      // a lie when the check never completed.
      expect(controller.checkNow, throwsA(isA<UpdateCheckFailure>()));
    });

    test(
      'does not record the time, so the daily check is unaffected',
      () async {
        final settings = await settingsWith(<String, Object>{});
        final controller = UpdateController(
          settings: settings,
          currentVersion: '0.1.0',
          check: publishing('0.2.0'),
        );

        await controller.checkNow();

        expect(settings.lastUpdateCheck, isNull);
      },
    );
  });

  group('UpdateController.dismiss', () {
    test('hides the current notice', () async {
      final controller = UpdateController(
        settings: await settingsWith(<String, Object>{
          'flutter.update_check_enabled': true,
        }),
        currentVersion: '0.1.0',
        check: publishing('0.2.0'),
      );
      await controller.checkIfDue();
      expect(controller.availableVersion, '0.2.0');

      controller.dismiss();

      expect(controller.availableVersion, isNull);
    });

    test('a later version shows up again', () async {
      final settings = await settingsWith(<String, Object>{
        'flutter.update_check_enabled': true,
      });
      var version = '0.2.0';
      final controller = UpdateController(
        settings: settings,
        currentVersion: '0.1.0',
        check: UpdateCheck(
          fetch: (_) async => 'Package: paint\nVersion: $version\n',
        ),
      );

      await controller.checkIfDue(now: DateTime(2026, 8, 7));
      controller.dismiss();
      expect(controller.availableVersion, isNull);

      version = '0.3.0';
      await controller.checkIfDue(now: DateTime(2026, 8, 9));

      // Dismissing 0.2.0 must not silence every future release.
      expect(controller.availableVersion, '0.3.0');
    });
  });
}
