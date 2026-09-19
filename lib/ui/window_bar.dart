import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../controller/document_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_menu_bar.dart';

/// The single bar across the top of the window.
///
/// The system title bar is switched off in `main.dart`, and this replaces it:
/// the menus, the document name and the window buttons share one row that is
/// painted in the application's own colours. That removes an entire row of
/// chrome and stops the window looking like two unrelated pieces stacked on
/// each other.
///
/// The cost of an undecorated GTK window is that moving and resizing become the
/// application's job — [WindowResizeEdges] restores the resize borders.
class WindowBar extends StatefulWidget {
  const WindowBar({super.key});

  @override
  State<WindowBar> createState() => _WindowBarState();
}

class _WindowBarState extends State<WindowBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted && maximized != _maximized) {
      setState(() => _maximized = maximized);
    }
  }

  Future<void> _toggleMaximized() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    final l10n = AppLocalizations.of(context);
    final documents = context.watch<DocumentController>();

    final name = documents.isReady
        ? documents.document.fileName ?? l10n.untitledDocument
        : l10n.untitledDocument;
    final title = documents.isReady && documents.document.isModified
        ? l10n.modifiedMarker(name)
        : name;

    return Container(
      height: theme.metrics.windowBarHeight,
      color: theme.palette.chrome,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 8),
          Image.asset('assets/icon/paint.png', width: 17, height: 17),
          const SizedBox(width: 6),
          const AppMenuBar(),
          // The gap between the menus and the buttons is the drag handle, and
          // it is where a double-click maximises, matching every other window.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximized,
              child: Align(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.dimTextStyle,
                ),
              ),
            ),
          ),
          _WindowButton(
            icon: SlateIcons.minimize,
            tooltip: l10n.windowMinimize,
            onPressed: windowManager.minimize,
          ),
          _WindowButton(
            icon: _maximized ? SlateIcons.restore : SlateIcons.maximize,
            tooltip: _maximized ? l10n.windowRestore : l10n.windowMaximize,
            onPressed: _toggleMaximized,
          ),
          _WindowButton(
            icon: SlateIcons.close,
            tooltip: l10n.windowClose,
            // Goes through close() rather than destroy() so the unsaved-changes
            // guard in AppShell.onWindowClose still runs.
            onPressed: windowManager.close,
            danger: true,
          ),
        ],
      ),
    );
  }
}

/// A window button: wider than tall and square-cornered, the shape every
/// desktop uses for this row. That is why it is not a [SlateIconButton], which
/// is a square control sized for a toolbar.
class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final SlateIconDraw icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Close gets a red hover, the one convention every desktop shares.
  final bool danger;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 42,
            height: theme.metrics.windowBarHeight,
            alignment: Alignment.center,
            color: !_hover
                ? const Color(0x00000000)
                : widget.danger
                ? theme.palette.danger
                : theme.palette.hover,
            child: SlateIcon(
              widget.icon,
              size: 14,
              color: widget.danger && _hover
                  ? const Color(0xFFFFFFFF)
                  : theme.palette.inkDim,
            ),
          ),
        ),
      ),
    );
  }
}

/// Invisible grips along the window edges.
///
/// An undecorated GTK window has no resize borders of its own, so without these
/// the window could only ever be resized by maximising it.
class WindowResizeEdges extends StatelessWidget {
  const WindowResizeEdges({super.key});

  /// Grip thickness. Wide enough to hit comfortably, narrow enough not to steal
  /// clicks from the controls that sit near the window edge.
  static const double thickness = 5;

  /// Corner grips are bigger, because hitting an exact corner is fiddly.
  static const double corner = thickness * 2;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        _edge(
          ResizeEdge.left,
          SystemMouseCursors.resizeLeftRight,
          left: 0,
          top: 0,
          bottom: 0,
          width: thickness,
        ),
        _edge(
          ResizeEdge.right,
          SystemMouseCursors.resizeLeftRight,
          right: 0,
          top: 0,
          bottom: 0,
          width: thickness,
        ),
        _edge(
          ResizeEdge.top,
          SystemMouseCursors.resizeUpDown,
          left: 0,
          right: 0,
          top: 0,
          height: thickness,
        ),
        _edge(
          ResizeEdge.bottom,
          SystemMouseCursors.resizeUpDown,
          left: 0,
          right: 0,
          bottom: 0,
          height: thickness,
        ),
        // Corners last, so they win over the edges they overlap.
        _edge(
          ResizeEdge.topLeft,
          SystemMouseCursors.resizeUpLeftDownRight,
          left: 0,
          top: 0,
          width: corner,
          height: corner,
        ),
        _edge(
          ResizeEdge.topRight,
          SystemMouseCursors.resizeUpRightDownLeft,
          right: 0,
          top: 0,
          width: corner,
          height: corner,
        ),
        _edge(
          ResizeEdge.bottomLeft,
          SystemMouseCursors.resizeUpRightDownLeft,
          left: 0,
          bottom: 0,
          width: corner,
          height: corner,
        ),
        _edge(
          ResizeEdge.bottomRight,
          SystemMouseCursors.resizeUpLeftDownRight,
          right: 0,
          bottom: 0,
          width: corner,
          height: corner,
        ),
      ],
    );
  }

  static Widget _edge(
    ResizeEdge edge,
    MouseCursor cursor, {
    double? left,
    double? right,
    double? top,
    double? bottom,
    double? width,
    double? height,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => windowManager.startResizing(edge),
        ),
      ),
    );
  }
}
