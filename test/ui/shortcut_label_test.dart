import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paint/l10n/generated/app_localizations_en.dart';
import 'package:paint/ui/shortcut_label.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('shortcutLabel', () {
    test('names the modifier and the key', () {
      expect(
        shortcutLabel(
          l10n,
          const SingleActivator(LogicalKeyboardKey.keyN, control: true),
        ),
        'Ctrl+N',
      );
    });

    test('orders modifiers the way every menu writes them', () {
      expect(
        shortcutLabel(
          l10n,
          const SingleActivator(
            LogicalKeyboardKey.keyS,
            control: true,
            shift: true,
          ),
        ),
        'Ctrl+Shift+S',
      );
      expect(
        shortcutLabel(
          l10n,
          const SingleActivator(
            LogicalKeyboardKey.keyF,
            control: true,
            alt: true,
          ),
        ),
        'Ctrl+Alt+F',
      );
    });

    test('an unmodified key stands alone', () {
      expect(
        shortcutLabel(l10n, const SingleActivator(LogicalKeyboardKey.delete)),
        l10n.keyDelete,
      );
    });

    // Digits and punctuation carry their own label, which is why only the
    // named keys need a translation of their own.
    test('digits and punctuation use the key label', () {
      expect(
        shortcutLabel(
          l10n,
          const SingleActivator(LogicalKeyboardKey.digit0, control: true),
        ),
        'Ctrl+0',
      );
      expect(
        shortcutLabel(
          l10n,
          const SingleActivator(LogicalKeyboardKey.minus, control: true),
        ),
        'Ctrl+-',
      );
    });
  });
}
