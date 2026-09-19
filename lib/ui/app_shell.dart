import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../controller/canvas_controller.dart';
import '../controller/document_controller.dart';
import '../controller/update_controller.dart';
import '../io/image_codecs.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/tool_settings.dart';
import '../tools/tool_registry.dart';
import 'app_actions.dart';
import 'canvas_view.dart';
import 'color_panel.dart';
import 'status_bar.dart';
import 'tool_options_bar.dart';
import 'tool_palette.dart';
import 'window_bar.dart';

/// The window layout: menu, tool options, palette, canvas, colours, status.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncWindowTitle();
    // After the first frame, so a slow or hanging network never delays the
    // window appearing. Does nothing at all unless the user enabled checks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UpdateController>().checkIfDue();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// The window is set to prevent close so unsaved work can be rescued first.
  @override
  void onWindowClose() async {
    final actions = AppActions(context);
    if (await actions.confirmClose()) {
      await windowManager.destroy();
    }
  }

  void _syncWindowTitle() {
    final documents = context.read<DocumentController>();
    if (!documents.isReady) return;
    final l10n = AppLocalizations.of(context);
    final name = documents.document.fileName ?? l10n.untitledDocument;
    final marked = documents.document.isModified
        ? l10n.modifiedMarker(name)
        : name;
    unawaited(windowManager.setTitle(l10n.windowTitle(marked)));
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds on every document change, which is also when the title's
    // dirty marker needs refreshing.
    context.watch<DocumentController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWindowTitle());

    return _ShortcutScope(
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                const WindowBar(),
                const SlateSeparator(),
                const ToolOptionsBar(),
                const SlateSeparator(),
                Expanded(
                  child: Row(
                    // Stretch, or the palette sizes itself to its icons and floats
                    // in the vertical middle instead of starting at the top.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const ToolPalette(),
                      const SlateSeparator(vertical: true),
                      Expanded(
                        child: _DropTarget(
                          dragging: _dragging,
                          onDraggingChanged: (value) =>
                              setState(() => _dragging = value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SlateSeparator(),
                const ColorPanel(),
                const SlateSeparator(),
                const StatusBar(),
              ],
            ),
            // Above the content so the grips are reachable even where a panel
            // reaches the window edge.
            const WindowResizeEdges(),
          ],
        ),
      ),
    );
  }
}

/// Wraps the canvas so a file dropped anywhere over it opens.
class _DropTarget extends StatelessWidget {
  const _DropTarget({required this.dragging, required this.onDraggingChanged});

  final bool dragging;
  final ValueChanged<bool> onDraggingChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;

    return DropTarget(
      onDragEntered: (_) => onDraggingChanged(true),
      onDragExited: (_) => onDraggingChanged(false),
      onDragDone: (details) async {
        onDraggingChanged(false);
        final paths = details.files
            .map((file) => file.path)
            .where((path) => ImageCodecs.formatForPath(path) != null)
            .toList();
        if (paths.isEmpty) return;
        // Only the first file is opened: this build has a single document, so
        // opening the rest would silently discard them.
        if (context.mounted) await AppActions(context).openPath(paths.first);
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const CanvasView(),
          if (dragging)
            IgnorePointer(
              child: Container(
                color: theme.palette.accent.withValues(alpha: 0.12),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: theme.popoverDecoration,
                  child: Text(l10n.dropHint, style: theme.textStyle),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Application-wide keyboard shortcuts.
///
/// Registered above the canvas rather than on it so they work regardless of
/// which panel has focus.
///
/// The unmodified bindings — tool letters, arrows, Delete — are withdrawn while
/// the on-canvas text editor is open. Handling a key here stops it reaching the
/// text input plugin, so leaving them bound silently swallows every character
/// that happens to be a tool shortcut: typing "Hello" would switch tools and
/// insert only "H". Dialogs are unaffected, because their routes sit above this
/// widget in the Navigator's overlay rather than below it.
class _ShortcutScope extends StatelessWidget {
  const _ShortcutScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final actions = AppActions(context);
    final tools = context.read<ToolSettings>();
    final editingText = context.watch<CanvasController>().textSession != null;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            actions.newImage,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            actions.open,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            actions.save,
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ): actions.saveAs,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            actions.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            actions.redo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): actions.redo,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true):
            actions.cut,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            actions.copy,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            actions.paste,
        const SingleActivator(LogicalKeyboardKey.equal, control: true):
            actions.zoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            actions.zoomOut,
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            actions.zoomActualSize,
        const SingleActivator(LogicalKeyboardKey.digit9, control: true):
            actions.zoomFit,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            actions.resizeImage,
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            actions.stretchAndSkew,
        const SingleActivator(LogicalKeyboardKey.keyI, control: true):
            actions.invertColors,
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            actions.selectAll,
        const SingleActivator(
          LogicalKeyboardKey.keyA,
          control: true,
          shift: true,
        ): actions.deselect,
        const SingleActivator(
          LogicalKeyboardKey.keyX,
          control: true,
          shift: true,
        ): actions.cropToSelection,
        const SingleActivator(LogicalKeyboardKey.escape):
            actions.cancelOrDeselect,
        if (!editingText) ...<ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.delete):
              actions.deleteSelection,
          // Nudge the selection one image pixel at a time.
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              actions.nudgeSelection(const Offset(-1, 0)),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              actions.nudgeSelection(const Offset(1, 0)),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              actions.nudgeSelection(const Offset(0, -1)),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              actions.nudgeSelection(const Offset(0, 1)),
          for (final tool in ToolRegistry.tools)
            SingleActivator(
              _letterFor(ToolRegistry.shortcutFor(tool.id)),
            ): () =>
                tools.activeTool = tool.id,
        },
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  static LogicalKeyboardKey _letterFor(String letter) {
    return LogicalKeyboardKey(
      LogicalKeyboardKey.keyA.keyId + (letter.codeUnitAt(0) - 0x41),
    );
  }
}

/// Fire-and-forget for window-manager calls whose result nothing waits on.
void unawaited(Future<void> future) {
  future.catchError((Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'paint'),
    );
  });
}
