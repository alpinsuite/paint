import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/document_controller.dart';
import '../controller/update_controller.dart';
import '../core/app_version.dart';
import '../core/settings/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_actions.dart';
import 'dialogs.dart';
import 'shortcut_label.dart';

/// The application menu, rendered in-app rather than through a GTK menu bar.
///
/// Flutter's [PlatformMenuBar] has no Linux backend, and an in-app menu keeps
/// the theme consistent across the whole window.
///
/// The panels are built lazily by [SlateMenuButton], so the recent-files list
/// and the enabled state of every command are read when the menu opens rather
/// than captured when the bar was last laid out.
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // No height or background of its own: it is embedded in WindowBar, which
    // supplies both so the menus and the window buttons read as one bar.
    return SlateMenuBar(
      children: <Widget>[
        SlateMenuButton(label: l10n.menuFile, items: _fileMenu),
        SlateMenuButton(label: l10n.menuEdit, items: _editMenu),
        SlateMenuButton(label: l10n.menuView, items: _viewMenu),
        SlateMenuButton(label: l10n.menuImage, items: _imageMenu),
        SlateMenuButton(label: l10n.menuHelp, items: _helpMenu),
      ],
    );
  }

  static List<Widget> _fileMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = AppActions(context);
    final settings = context.watch<SettingsController>();
    final recentFiles = settings.recentFiles;

    return <Widget>[
      _item(
        context,
        l10n.actionNew,
        _ctrl(LogicalKeyboardKey.keyN),
        actions.newImage,
      ),
      _item(
        context,
        l10n.actionOpen,
        _ctrl(LogicalKeyboardKey.keyO),
        actions.open,
      ),
      _item(
        context,
        l10n.actionSave,
        _ctrl(LogicalKeyboardKey.keyS),
        actions.save,
      ),
      _item(
        context,
        l10n.actionSaveAs,
        _ctrl(LogicalKeyboardKey.keyS, shift: true),
        actions.saveAs,
      ),
      const SlateMenuSeparator(),
      SlateSubmenu(
        label: l10n.actionRecentFiles,
        items: (context) => <Widget>[
          if (recentFiles.isEmpty)
            SlateMenuItem(label: l10n.actionNoRecentFiles, onPressed: null)
          else ...<Widget>[
            for (final path in recentFiles)
              SlateMenuItem(
                label: path.split('/').last,
                onPressed: () => actions.openPath(path),
              ),
            const SlateMenuSeparator(),
            SlateMenuItem(
              label: l10n.actionClearRecentFiles,
              onPressed: settings.clearRecentFiles,
            ),
          ],
        ],
      ),
      const SlateMenuSeparator(),
      _item(
        context,
        l10n.actionQuit,
        _ctrl(LogicalKeyboardKey.keyQ),
        () => _quit(context),
      ),
    ];
  }

  static List<Widget> _editMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = AppActions(context);
    final documents = context.watch<DocumentController>();

    return <Widget>[
      _item(
        context,
        l10n.actionUndo,
        _ctrl(LogicalKeyboardKey.keyZ),
        documents.canUndo ? actions.undo : null,
      ),
      _item(
        context,
        l10n.actionRedo,
        _ctrl(LogicalKeyboardKey.keyY),
        documents.canRedo ? actions.redo : null,
      ),
      const SlateMenuSeparator(),
      _item(
        context,
        l10n.actionCut,
        _ctrl(LogicalKeyboardKey.keyX),
        actions.cut,
      ),
      _item(
        context,
        l10n.actionCopy,
        _ctrl(LogicalKeyboardKey.keyC),
        actions.copy,
      ),
      _item(
        context,
        l10n.actionPaste,
        _ctrl(LogicalKeyboardKey.keyV),
        actions.paste,
      ),
      _item(
        context,
        l10n.actionDelete,
        const SingleActivator(LogicalKeyboardKey.delete),
        actions.deleteSelection,
      ),
      const SlateMenuSeparator(),
      _item(
        context,
        l10n.actionSelectAll,
        _ctrl(LogicalKeyboardKey.keyA),
        actions.selectAll,
      ),
      _item(
        context,
        l10n.actionDeselect,
        _ctrl(LogicalKeyboardKey.keyA, shift: true),
        actions.deselect,
      ),
      SlateMenuItem(
        label: l10n.actionInvertSelection,
        onPressed: actions.invertSelection,
      ),
      _item(
        context,
        l10n.actionCropToSelection,
        _ctrl(LogicalKeyboardKey.keyX, shift: true),
        actions.cropToSelection,
      ),
      const SlateMenuSeparator(),
      SlateMenuItem(label: l10n.actionPasteFrom, onPressed: actions.pasteFrom),
      SlateMenuItem(label: l10n.actionCopyTo, onPressed: actions.copyTo),
    ];
  }

  static List<Widget> _viewMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = AppActions(context);
    final settings = context.watch<SettingsController>();

    return <Widget>[
      _item(
        context,
        l10n.actionZoomIn,
        _ctrl(LogicalKeyboardKey.equal),
        actions.zoomIn,
      ),
      _item(
        context,
        l10n.actionZoomOut,
        _ctrl(LogicalKeyboardKey.minus),
        actions.zoomOut,
      ),
      _item(
        context,
        l10n.actionZoomNormal,
        _ctrl(LogicalKeyboardKey.digit0),
        actions.zoomActualSize,
      ),
      _item(
        context,
        l10n.actionZoomFit,
        _ctrl(LogicalKeyboardKey.digit9),
        actions.zoomFit,
      ),
      const SlateMenuSeparator(),
      SlateSubmenu(
        label: l10n.actionToggleTheme,
        items: (context) => <Widget>[
          for (final mode in ThemeMode.values)
            SlateMenuItem(
              label: switch (mode) {
                ThemeMode.system => l10n.themeSystem,
                ThemeMode.light => l10n.themeLight,
                ThemeMode.dark => l10n.themeDark,
              },
              checked: settings.themeMode == mode,
              onPressed: () => actions.setThemeMode(mode),
            ),
        ],
      ),
    ];
  }

  static List<Widget> _imageMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = AppActions(context);

    return <Widget>[
      SlateMenuItem(
        label: l10n.imageFlipHorizontal,
        onPressed: actions.flipHorizontal,
      ),
      SlateMenuItem(
        label: l10n.imageFlipVertical,
        onPressed: actions.flipVertical,
      ),
      const SlateMenuSeparator(),
      SlateMenuItem(
        label: l10n.imageRotate90Right,
        onPressed: () => actions.rotate(1),
      ),
      SlateMenuItem(
        label: l10n.imageRotate90Left,
        onPressed: () => actions.rotate(3),
      ),
      SlateMenuItem(
        label: l10n.imageRotate180,
        onPressed: () => actions.rotate(2),
      ),
      const SlateMenuSeparator(),
      _item(
        context,
        l10n.imageResize,
        _ctrl(LogicalKeyboardKey.keyR),
        actions.resizeImage,
      ),
      SlateMenuItem(label: l10n.imageCanvasSize, onPressed: actions.canvasSize),
      _item(
        context,
        l10n.imageStretchSkew,
        _ctrl(LogicalKeyboardKey.keyW),
        actions.stretchAndSkew,
      ),
      const SlateMenuSeparator(),
      _item(
        context,
        l10n.imageInvertColors,
        _ctrl(LogicalKeyboardKey.keyI),
        actions.invertColors,
      ),
      SlateMenuItem(label: l10n.imageClear, onPressed: actions.clearImage),
    ];
  }

  static List<Widget> _helpMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsController>();
    final updates = context.watch<UpdateController>();

    return <Widget>[
      SlateMenuItem(
        label: l10n.actionCheckUpdatesNow,
        onPressed: updates.isChecking
            ? null
            : () => AppActions(context).checkForUpdates(),
      ),
      SlateMenuItem(
        label: l10n.actionAutoCheckUpdates,
        checked: settings.updateCheckEnabled,
        // Left open: a switch is something people flick and then look at.
        closesMenu: false,
        onPressed: () =>
            settings.setUpdateCheckEnabled(!settings.updateCheckEnabled),
      ),
      const SlateMenuSeparator(),
      SlateMenuItem(
        label: l10n.actionAbout,
        onPressed: () => showAboutPaintDialog(context, appVersion),
      ),
    ];
  }

  static SingleActivator _ctrl(LogicalKeyboardKey key, {bool shift = false}) =>
      SingleActivator(key, control: true, shift: shift);

  static Widget _item(
    BuildContext context,
    String label,
    SingleActivator shortcut,
    VoidCallback? onPressed,
  ) {
    return SlateMenuItem(
      label: label,
      shortcut: shortcutLabel(AppLocalizations.of(context), shortcut),
      onPressed: onPressed,
    );
  }

  static Future<void> _quit(BuildContext context) async {
    if (await AppActions(context).confirmClose()) {
      // Popping the root route ends the app on desktop.
      if (context.mounted) await Navigator.of(context).maybePop();
    }
  }
}
