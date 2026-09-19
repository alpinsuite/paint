import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences that outlive a session.
///
/// Everything here is best-effort: if persistence fails the app still runs with
/// the defaults, because losing a preference must never block editing.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  static const _keyThemeMode = 'theme_mode';
  static const _keyRecentFiles = 'recent_files';
  static const _keyUndoBudgetMb = 'undo_budget_mb';
  static const _keyDefaultWidth = 'default_width';
  static const _keyDefaultHeight = 'default_height';
  static const _keyJpegQuality = 'jpeg_quality';
  static const _keyCustomColors = 'custom_colors';
  static const _keyUpdateCheckEnabled = 'update_check_enabled';
  static const _keyLastUpdateCheck = 'last_update_check';

  /// How many recent files the File menu remembers.
  static const int maxRecentFiles = 10;

  final SharedPreferences _prefs;

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController(prefs);
  }

  ThemeMode get themeMode {
    return switch (_prefs.getString(_keyThemeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_keyThemeMode, mode.name);
    notifyListeners();
  }

  /// Most recently opened files, newest first. Paths that no longer exist are
  /// filtered out on read so the menu never offers a dead entry.
  List<String> get recentFiles {
    final stored = _prefs.getStringList(_keyRecentFiles) ?? const <String>[];
    return stored.where((path) => File(path).existsSync()).toList();
  }

  Future<void> addRecentFile(String path) async {
    final updated = <String>[
      path,
      ..._prefs.getStringList(_keyRecentFiles)?.where((p) => p != path) ??
          const <String>[],
    ];
    if (updated.length > maxRecentFiles) {
      updated.removeRange(maxRecentFiles, updated.length);
    }
    await _prefs.setStringList(_keyRecentFiles, updated);
    notifyListeners();
  }

  Future<void> clearRecentFiles() async {
    await _prefs.remove(_keyRecentFiles);
    notifyListeners();
  }

  /// Memory ceiling for the undo stack, in megabytes. Undo entries are evicted
  /// oldest-first once the stack exceeds this.
  int get undoBudgetMb => _prefs.getInt(_keyUndoBudgetMb) ?? 512;

  Future<void> setUndoBudgetMb(int value) async {
    await _prefs.setInt(_keyUndoBudgetMb, value.clamp(64, 4096));
    notifyListeners();
  }

  /// Size pre-filled in the New Image dialog.
  Size get defaultImageSize => Size(
    (_prefs.getInt(_keyDefaultWidth) ?? 800).toDouble(),
    (_prefs.getInt(_keyDefaultHeight) ?? 600).toDouble(),
  );

  Future<void> setDefaultImageSize(int width, int height) async {
    await _prefs.setInt(_keyDefaultWidth, width);
    await _prefs.setInt(_keyDefaultHeight, height);
    notifyListeners();
  }

  /// Whether the application may ask the repository, once a day, if a newer
  /// version has been published.
  ///
  /// Off unless the user turns it on. This is the only thing in the program
  /// that opens a socket, and "no network" is a promise the README makes; it
  /// stays true for anyone who never touches this switch.
  bool get updateCheckEnabled =>
      _prefs.getBool(_keyUpdateCheckEnabled) ?? false;

  Future<void> setUpdateCheckEnabled(bool value) async {
    await _prefs.setBool(_keyUpdateCheckEnabled, value);
    notifyListeners();
  }

  /// When the last automatic check ran, so a daily one is not a per-launch one.
  DateTime? get lastUpdateCheck {
    final millis = _prefs.getInt(_keyLastUpdateCheck);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastUpdateCheck(DateTime when) async {
    await _prefs.setInt(_keyLastUpdateCheck, when.millisecondsSinceEpoch);
    notifyListeners();
  }

  int get jpegQuality => _prefs.getInt(_keyJpegQuality) ?? 92;

  Future<void> setJpegQuality(int value) async {
    await _prefs.setInt(_keyJpegQuality, value.clamp(1, 100));
    notifyListeners();
  }

  /// Colours the user mixed in the colour dialog, newest first.
  List<Color> get customColors {
    final stored = _prefs.getStringList(_keyCustomColors) ?? const <String>[];
    return stored
        .map(int.tryParse)
        .whereType<int>()
        .map((value) => Color(value))
        .toList();
  }

  Future<void> addCustomColor(Color color) async {
    final value = color.toARGB32().toString();
    final updated = <String>[
      value,
      ..._prefs.getStringList(_keyCustomColors)?.where((v) => v != value) ??
          const <String>[],
    ];
    const maxCustomColors = 16;
    if (updated.length > maxCustomColors) {
      updated.removeRange(maxCustomColors, updated.length);
    }
    await _prefs.setStringList(_keyCustomColors, updated);
    notifyListeners();
  }
}
