import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/selection.dart';
import '../model/tool_settings.dart';
import '../tools/selection_tools.dart';
import '../tools/text_tool.dart';
import '../tools/tool.dart';
import '../tools/tool_registry.dart';
import 'document_controller.dart';
import 'selection_controller.dart';
import 'viewport_controller.dart';

/// An in-progress on-canvas text entry.
class TextSession {
  TextSession({required this.anchor})
    : controller = TextEditingController(),
      focusNode = FocusNode(debugLabel: 'canvas-text');

  /// Top-left of the text, in image coordinates.
  final ui.Offset anchor;
  final TextEditingController controller;
  final FocusNode focusNode;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// Turns pointer and keyboard input into tool gestures.
///
/// Sits between the canvas widget and [DocumentController]: the widget reports
/// raw events, this decides whether they pan the view, drive a tool, or start a
/// text session, and only completed gestures reach the document.
class CanvasController extends ChangeNotifier {
  CanvasController({
    required this.documents,
    required this.settings,
    required this.viewport,
    required this.selections,
  }) {
    settings.addListener(_onSettingsChanged);
  }

  final DocumentController documents;
  final ToolSettings settings;
  final ViewportController viewport;
  final SelectionController selections;

  /// How close, in screen pixels, a press must land to a resize handle to grab
  /// it. Converted to image pixels using the current zoom so the target stays
  /// the same physical size however far in the user is zoomed.
  static const double handleHitRadius = 7;

  ToolGesture? _gesture;
  TextSession? _textSession;
  ui.Offset? _cursorImagePosition;
  bool _panning = false;
  ui.Offset _lastPanPoint = ui.Offset.zero;
  ToolModifiers _modifiers = const ToolModifiers();

  /// The gesture currently being dragged, for the live preview.
  ToolGesture? get gesture => _gesture;

  TextSession? get textSession => _textSession;

  /// Cursor position in image coordinates, or null when it is off the canvas.
  ui.Offset? get cursorImagePosition => _cursorImagePosition;

  Tool? get activeTool => ToolRegistry.byId(settings.activeTool);

  MouseCursor get cursor {
    if (_panning) return SystemMouseCursors.grabbing;
    final overSelection = selectionCursorAt(_cursorImagePosition);
    if (overSelection != null) return overSelection;
    return activeTool?.cursor ?? SystemMouseCursors.basic;
  }

  void _onSettingsChanged() {
    // Switching tool mid-gesture finishes what was in progress rather than
    // silently discarding the user's work.
    if (_gesture != null) _finishGesture(commit: _gesture!.cancel());
  }

  ToolContext _context(ToolModifiers modifiers) {
    return ToolContext(
      settings: settings,
      document: documents.document,
      controller: documents,
      selection: selections,
      modifiers: modifiers,
      requestRepaint: notifyListeners,
      pickColor: (color, {required secondary}) {
        if (secondary) {
          settings.secondaryColor = color;
        } else {
          settings.primaryColor = color;
        }
      },
      startTextSession: _startTextSession,
    );
  }

  ToolModifiers _readModifiers({bool secondaryButton = false}) {
    final keyboard = HardwareKeyboard.instance;
    return ToolModifiers(
      shift: keyboard.isShiftPressed,
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      secondaryButton: secondaryButton,
    );
  }

  void pointerDown(PointerDownEvent event) {
    if (!documents.isReady) return;

    // Middle button always pans, so a zoomed-in image can be navigated without
    // leaving the current tool.
    if (event.buttons & kMiddleMouseButton != 0) {
      _panning = true;
      _lastPanPoint = event.localPosition;
      notifyListeners();
      return;
    }

    final secondary = event.buttons & kSecondaryMouseButton != 0;
    _modifiers = _readModifiers(secondaryButton: secondary);
    final point = viewport.toImage(event.localPosition);

    // A click elsewhere ends an open text session by committing it, the same
    // way Paint anchors its text box.
    if (_textSession != null) {
      commitTextSession();
      return;
    }

    final existing = _gesture;
    if (existing != null) {
      // Multi-click tools (polygon, curve) keep the same gesture across clicks.
      if (existing.release(point, _modifiers)) {
        _finishGesture(commit: true);
      }
      return;
    }

    final tool = activeTool;
    if (tool == null) return;

    // A press on an existing selection moves or resizes it instead of starting
    // a new one — otherwise a selection could never be repositioned.
    final dragGesture = _selectionDragAt(point);
    if (dragGesture != null) {
      _gesture = dragGesture;
      notifyListeners();
      return;
    }

    final context = _context(_modifiers);
    final gesture = tool.begin(context, point);
    if (gesture == null) {
      unawaited(tool.tap(context, point));
      return;
    }
    _gesture = gesture;
    notifyListeners();
  }

  void pointerMove(PointerMoveEvent event) {
    if (_panning) {
      viewport.panBy(event.localPosition - _lastPanPoint);
      _lastPanPoint = event.localPosition;
      return;
    }
    _cursorImagePosition = viewport.toImage(event.localPosition);
    final gesture = _gesture;
    if (gesture == null) {
      notifyListeners();
      return;
    }
    _modifiers = _readModifiers(secondaryButton: _modifiers.secondaryButton);
    gesture.update(_cursorImagePosition!, _modifiers);
  }

  void pointerHover(PointerHoverEvent event) {
    _cursorImagePosition = viewport.toImage(event.localPosition);
    final gesture = _gesture;
    if (gesture != null) {
      // Polygon and curve track the cursor between clicks, with no button held.
      gesture.update(_cursorImagePosition!, _readModifiers());
      return;
    }
    notifyListeners();
  }

  void pointerUp(PointerUpEvent event) {
    if (_panning) {
      _panning = false;
      notifyListeners();
      return;
    }
    final gesture = _gesture;
    if (gesture == null) return;
    final point = viewport.toImage(event.localPosition);
    _modifiers = _readModifiers(secondaryButton: _modifiers.secondaryButton);
    if (gesture.release(point, _modifiers)) {
      _finishGesture(commit: true);
    }
  }

  /// Returns a move/resize gesture when [point] lands on the current
  /// selection, or null when it does not.
  ToolGesture? _selectionDragAt(ui.Offset point) {
    final current = selections.selection;
    if (current == null || current.isEmpty) return null;
    final isSelectionTool =
        settings.activeTool == ToolId.selectRectangle ||
        settings.activeTool == ToolId.selectFreeform;
    if (!isSelectionTool) return null;

    final tolerance = handleHitRadius / viewport.zoom;
    final handle = current.handleAt(point, tolerance);
    if (handle == null && !current.contains(point)) return null;

    return SelectionDragGesture(
      selection: selections,
      requestRepaint: notifyListeners,
      eraseColor: settings.selectionTransparent
          ? const ui.Color(0x00000000)
          : settings.secondaryColor,
      handle: handle,
      start: point,
    );
  }

  /// Cursor for the selection handle under [point], if any.
  MouseCursor? selectionCursorAt(ui.Offset? point) {
    if (point == null) return null;
    final current = selections.selection;
    if (current == null || current.isEmpty) return null;
    final handle = current.handleAt(point, handleHitRadius / viewport.zoom);
    return switch (handle) {
      SelectionHandle.topLeft ||
      SelectionHandle.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
      SelectionHandle.topRight ||
      SelectionHandle.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
      SelectionHandle.topCenter ||
      SelectionHandle.bottomCenter => SystemMouseCursors.resizeUpDown,
      SelectionHandle.centerLeft ||
      SelectionHandle.centerRight => SystemMouseCursors.resizeLeftRight,
      null => current.contains(point) ? SystemMouseCursors.move : null,
    };
  }

  void pointerExit() {
    _cursorImagePosition = null;
    notifyListeners();
  }

  /// Escape: abandon the gesture, or commit the part of it worth keeping.
  void cancelGesture() {
    final gesture = _gesture;
    if (gesture == null) return;
    _finishGesture(commit: gesture.cancel());
  }

  void _finishGesture({required bool commit}) {
    final gesture = _gesture;
    _gesture = null;
    if (gesture == null) return;
    if (commit && gesture.modifiesBitmap) {
      unawaited(
        documents.commitRegion(
          bounds: gesture.bounds,
          draw: gesture.draw,
          label: gesture.label,
        ),
      );
    }
    notifyListeners();
  }

  void _startTextSession(ui.Offset at) {
    _textSession?.dispose();
    final session = TextSession(anchor: at);
    _textSession = session;
    notifyListeners();
    // Focus after the overlay has been built, or the request lands on a node
    // that is not yet in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      session.focusNode.requestFocus();
    });
  }

  /// Bakes the text being typed into the bitmap and closes the editor.
  void commitTextSession() {
    final session = _textSession;
    if (session == null) return;
    final text = session.controller.text;
    _textSession = null;

    if (text.isNotEmpty) {
      final painter = TextRendering.painterFor(
        text: text,
        settings: settings,
        color: settings.primaryColor,
      );
      final anchor = session.anchor;
      final background = settings.textOpaqueBackground
          ? settings.secondaryColor
          : null;
      final rect = ui.Rect.fromLTWH(
        anchor.dx,
        anchor.dy,
        painter.width,
        painter.height,
      );
      unawaited(
        documents.commitRegion(
          bounds: rect.inflate(2),
          label: 'Text',
          draw: (canvas) {
            if (background != null) {
              canvas.drawRect(rect, ui.Paint()..color = background);
            }
            painter.paint(canvas, anchor);
          },
        ),
      );
    }

    session.dispose();
    notifyListeners();
  }

  void cancelTextSession() {
    _textSession?.dispose();
    _textSession = null;
    notifyListeners();
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    _textSession?.dispose();
    super.dispose();
  }
}

/// Fire-and-forget for the commits whose completion nothing waits on.
///
/// Errors still surface: [DocumentController] serialises edits and rethrows,
/// and an unhandled rejection here would be reported by the zone.
void unawaited(Future<void> future) {
  future.catchError((Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'paint'),
    );
  });
}
