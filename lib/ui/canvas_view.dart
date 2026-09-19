import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controller/canvas_controller.dart';
import '../controller/document_controller.dart';
import '../controller/selection_controller.dart';
import '../controller/viewport_controller.dart';
import '../core/theme/app_theme.dart';
import '../model/tool_settings.dart';
import '../tools/text_tool.dart';
import 'canvas_painter.dart';

/// The drawing surface: the image, the live tool preview and the on-canvas
/// text editor.
class CanvasView extends StatelessWidget {
  const CanvasView({super.key});

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentController>();
    final viewport = context.read<ViewportController>();
    final canvas = context.watch<CanvasController>();
    final selections = context.watch<SelectionController>();

    if (!documents.isReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final document = documents.document;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = ui.Size(constraints.maxWidth, constraints.maxHeight);
        // Geometry has to settle before the frame is painted, but calling into
        // a ChangeNotifier during build would trigger a rebuild-in-build
        // assertion, so it is deferred by one frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          viewport.updateGeometry(viewport: size, image: document.size);
        });

        return Listener(
          onPointerDown: canvas.pointerDown,
          onPointerMove: canvas.pointerMove,
          onPointerUp: canvas.pointerUp,
          onPointerHover: canvas.pointerHover,
          onPointerSignal: (event) => _onPointerSignal(event, viewport),
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: canvas.cursor,
            onExit: (_) => canvas.pointerExit(),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                RepaintBoundary(
                  child: CustomPaint(
                    painter: CanvasPainter(
                      document: document,
                      viewport: viewport,
                      gesture: canvas.gesture,
                      selection: selections.selection,
                      colors: context.canvasColors,
                      repaint: Listenable.merge(<Listenable>[
                        documents,
                        viewport,
                        canvas,
                        selections,
                      ]),
                    ),
                  ),
                ),
                if (canvas.textSession != null)
                  _TextOverlay(session: canvas.textSession!),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The wheel zooms around the pointer; Shift+wheel scrolls sideways.
  ///
  /// Zoom is the default because it is what the wheel is for in an image
  /// editor. Panning is still available by dragging with the middle button,
  /// which works at any zoom and in any direction.
  static void _onPointerSignal(
    PointerSignalEvent event,
    ViewportController viewport,
  ) {
    if (event is! PointerScrollEvent) return;
    if (HardwareKeyboard.instance.isShiftPressed) {
      viewport.panBy(ui.Offset(-event.scrollDelta.dy, 0));
      return;
    }
    final factor = event.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15;
    viewport.zoomTo(viewport.zoom * factor, focalPoint: event.localPosition);
  }
}

class _TextOverlay extends StatelessWidget {
  const _TextOverlay({required this.session});

  final TextSession session;

  @override
  Widget build(BuildContext context) {
    final viewport = context.watch<ViewportController>();
    final settings = context.watch<ToolSettings>();
    final canvas = context.read<CanvasController>();

    final position = viewport.toScreen(session.anchor);
    final zoom = viewport.zoom;
    final style = TextRendering.styleFrom(
      settings,
      settings.primaryColor,
    ).copyWith(fontSize: settings.fontSize * zoom);

    return Positioned(
      left: position.dx,
      top: position.dy,
      // Room to type before the box needs to grow; the committed text is laid
      // out unconstrained, so this only bounds the editor.
      width: 420 * zoom.clamp(0.25, 2.0),
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.escape):
              const DismissIntent(),
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              const _CommitTextIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                canvas.cancelTextSession();
                return null;
              },
            ),
            _CommitTextIntent: CallbackAction<_CommitTextIntent>(
              onInvoke: (_) {
                canvas.commitTextSession();
                return null;
              },
            ),
          },
          child: Container(
            decoration: BoxDecoration(
              color: settings.textOpaqueBackground
                  ? settings.secondaryColor
                  : Colors.transparent,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 1,
              ),
            ),
            child: TextField(
              controller: session.controller,
              focusNode: session.focusNode,
              style: style,
              textAlign: settings.textAlign,
              maxLines: null,
              cursorWidth: 1,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommitTextIntent extends Intent {
  const _CommitTextIntent();
}
