import 'package:flutter/foundation.dart';

import '../core/settings/settings_controller.dart';
import '../io/update_check.dart';

/// Knows whether a newer Paint has been published, and nothing else.
///
/// It never downloads and never installs. The application is installed by dpkg
/// into a root-owned directory; replacing its own files would need privilege it
/// does not have and would leave the package database describing files that are
/// no longer there. `apt upgrade` is the mechanism, and this only says when
/// running it would achieve something.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.settings,
    required this.currentVersion,
    this.check = const UpdateCheck(),
  });

  /// How long an automatic check waits before running again.
  static const Duration checkInterval = Duration(days: 1);

  final SettingsController settings;
  final String currentVersion;

  /// Injected so a test can answer without a network.
  final UpdateCheck check;

  String? _available;
  String? _dismissed;
  bool _busy = false;

  /// The newer published version, or null when there is nothing to report or
  /// the user has dismissed what there was.
  String? get availableVersion => _available == _dismissed ? null : _available;

  /// True while a check is in flight, so an explicit one can show progress and
  /// cannot be started twice.
  bool get isChecking => _busy;

  /// Runs an automatic check if the user has enabled them and enough time has
  /// passed. Safe to call on every launch.
  Future<void> checkIfDue({DateTime? now}) async {
    if (!settings.updateCheckEnabled || _busy) return;
    final at = now ?? DateTime.now();
    final last = settings.lastUpdateCheck;
    if (last != null && at.difference(last) < checkInterval) return;
    await _run(at: at, recordTime: true);
  }

  /// Runs a check because the user asked for one, regardless of the setting and
  /// of when the last one ran. Asking is consent for this one check.
  ///
  /// Returns the newer version, or null when already current. Throws
  /// [UpdateCheckFailure] when the repository could not be reached, because
  /// somebody who pressed a button deserves to know it did not work.
  Future<String?> checkNow({DateTime? now}) async {
    if (_busy) return availableVersion;
    final latest = await _run(at: now ?? DateTime.now(), recordTime: false);
    if (latest == null) throw const UpdateCheckFailure();
    return isNewerVersion(latest, currentVersion) ? latest : null;
  }

  /// Puts the notice away until a different version shows up.
  void dismiss() {
    _dismissed = _available;
    notifyListeners();
  }

  /// The command that actually performs the upgrade. Not localised: it is typed
  /// into a shell, so translating it would break it.
  static const String upgradeCommand = 'sudo apt update && sudo apt upgrade';

  /// Returns the newest published version, or null if the check failed.
  Future<String?> _run({required DateTime at, required bool recordTime}) async {
    _busy = true;
    notifyListeners();
    try {
      final latest = await check.latestPublished();
      if (latest != null && isNewerVersion(latest, currentVersion)) {
        _available = latest;
      } else {
        // A newer version having appeared and then been withdrawn is not
        // something to keep advertising.
        _available = null;
      }
      if (recordTime) await settings.setLastUpdateCheck(at);
      return latest;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
