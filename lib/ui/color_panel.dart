import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../core/settings/settings_controller.dart';
import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/tool_settings.dart';
import 'color_picker_dialog.dart';

/// Primary/secondary swatches, the standard palette and the user's own colours.
class ColorPanel extends StatelessWidget {
  const ColorPanel({super.key});

  /// The classic 28-colour Paint palette: two rows of greys and saturated
  /// hues, which is what most users reach for without opening a picker.
  static const List<Color> palette = <Color>[
    Color(0xFF000000),
    Color(0xFF7F7F7F),
    Color(0xFF880015),
    Color(0xFFED1C24),
    Color(0xFFFF7F27),
    Color(0xFFFFF200),
    Color(0xFF22B14C),
    Color(0xFF00A2E8),
    Color(0xFF3F48CC),
    Color(0xFFA349A4),
    Color(0xFF404040),
    Color(0xFF606060),
    Color(0xFFB97A57),
    Color(0xFFFFAEC9),
    Color(0xFFFFFFFF),
    Color(0xFFC3C3C3),
    Color(0xFFB5E61D),
    Color(0xFF99D9EA),
    Color(0xFF7092BE),
    Color(0xFFC8BFE7),
    Color(0xFFEFE4B0),
    Color(0xFFFFC90E),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF808000),
    Color(0xFF800080),
    Color(0xFF008080),
    Color(0xFF000080),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ToolSettings>();
    final appSettings = context.watch<SettingsController>();
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final customColors = appSettings.customColors;

    return Container(
      color: theme.palette.panel,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _ActiveColors(settings: settings, l10n: l10n),
          const SizedBox(width: 12),
          const SlateSeparator(vertical: true),
          const SizedBox(width: 12),
          _Swatches(
            colors: palette,
            onPick: (color, secondary) => secondary
                ? settings.secondaryColor = color
                : settings.primaryColor = color,
          ),
          if (customColors.isNotEmpty) ...<Widget>[
            const SizedBox(width: 12),
            const SlateSeparator(vertical: true),
            const SizedBox(width: 12),
            Tooltip(
              message: l10n.colorRecent,
              child: _Swatches(
                colors: customColors,
                rows: 2,
                onPick: (color, secondary) => secondary
                    ? settings.secondaryColor = color
                    : settings.primaryColor = color,
              ),
            ),
          ],
          const SizedBox(width: 12),
          SlateButton(
            icon: SlateIcons.palette,
            label: l10n.colorEdit,
            onPressed: () => _editColor(context, settings, appSettings),
          ),
        ],
      ),
    );
  }

  Future<void> _editColor(
    BuildContext context,
    ToolSettings settings,
    SettingsController appSettings,
  ) async {
    final picked = await showColorPickerDialog(context, settings.primaryColor);
    if (picked == null) return;
    settings.primaryColor = picked;
    await appSettings.addCustomColor(picked);
  }
}

/// The overlapping primary/secondary swatches, with the swap affordance.
class _ActiveColors extends StatelessWidget {
  const _ActiveColors({required this.settings, required this.l10n});

  final ToolSettings settings;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 40,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 16,
            top: 14,
            child: _ColorWell(
              color: settings.secondaryColor,
              tooltip: l10n.colorSecondary,
              size: 22,
              onTap: () async {
                final picked = await showColorPickerDialog(
                  context,
                  settings.secondaryColor,
                );
                if (picked != null) settings.secondaryColor = picked;
              },
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _ColorWell(
              color: settings.primaryColor,
              tooltip: l10n.colorPrimary,
              size: 26,
              onTap: () async {
                final picked = await showColorPickerDialog(
                  context,
                  settings.primaryColor,
                );
                if (picked != null) settings.primaryColor = picked;
              },
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: SlateIconButton(
              icon: SlateIcons.swap,
              tooltip: l10n.colorSwapHint,
              size: 18,
              onPressed: settings.swapColors,
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors, required this.onPick, this.rows = 2});

  final List<Color> colors;
  final int rows;
  final void Function(Color color, bool secondary) onPick;

  @override
  Widget build(BuildContext context) {
    const cell = 15.0;
    final columns = (colors.length / rows).ceil();
    return SizedBox(
      height: cell * rows + (rows - 1),
      width: (cell + 1) * columns,
      child: Wrap(
        spacing: 1,
        runSpacing: 1,
        // Column-major so the palette reads as pairs of light/dark, the way
        // Paint lays it out.
        children: <Widget>[
          for (var column = 0; column < columns; column++)
            for (var row = 0; row < rows; row++)
              if (row * columns + column < colors.length)
                _SwatchCell(
                  color: colors[row * columns + column],
                  size: cell,
                  onPick: onPick,
                ),
        ],
      ),
    );
  }
}

class _SwatchCell extends StatelessWidget {
  const _SwatchCell({
    required this.color,
    required this.size,
    required this.onPick,
  });

  final Color color;
  final double size;
  final void Function(Color color, bool secondary) onPick;

  @override
  Widget build(BuildContext context) {
    // Right-click assigns the secondary colour, mirroring right-drag drawing.
    return GestureDetector(
      onTap: () => onPick(color, false),
      onSecondaryTap: () => onPick(color, true),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: context.slateColors.border),
        ),
      ),
    );
  }
}

class _ColorWell extends StatelessWidget {
  const _ColorWell({
    required this.color,
    required this.tooltip,
    required this.size,
    required this.onTap,
  });

  final Color color;
  final String tooltip;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canvasColors = context.canvasColors;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(color: canvasColors.handleBorder),
            // Checker behind the well so a translucent colour reads as such.
            color: canvasColors.checkerLight,
          ),
          child: Container(color: color),
        ),
      ),
    );
  }
}
