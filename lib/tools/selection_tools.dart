import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../controller/selection_controller.dart';
import '../model/selection.dart';
import '../model/tool_settings.dart';
import 'tool.dart';

/// Base for the gestures that mark out a new selection.
///
/// These never touch the bitmap — [modifiesBitmap] is false — they only hand a
/// [Selection] to the [SelectionController] when the drag ends.
abstract class _SelectionGesture extends ToolGesture {
  _SelectionGesture({
    required this.selection,
    required this.requestRepaint,
    required this.imageBounds,
  });

  final SelectionController selection;
  final VoidCallback requestRepaint;
  final ui.Rect imageBounds;

  @override
  bool get modifiesBitmap => false;

  @override
  String get label => 'Select';

  @override
  void draw(ui.Canvas canvas) {}

  /// The shape marked out so far, or null when it is too small to be useful.
  ui.Path? buildPath();

  @override
  bool release(ui.Offset point, ToolModifiers modifiers) {
    update(point, modifiers);
    final path = buildPath();
    if (path == null) {
      unawaited(selection.deselect());
      return true;
    }
    // Clip to the canvas so a drag that runs off the edge does not produce a
    // selection whose pixels partly do not exist.
    final clipped = ui.Path.combine(
      ui.PathOperation.intersect,
      ui.Path()..addRect(imageBounds),
      path,
    );
    final bounds = clipped.getBounds();
    if (bounds.width < 1 || bounds.height < 1) {
      unawaited(selection.deselect());
      return true;
    }
    unawaited(
      selection.replace(
        Selection(path: clipped, originalBounds: bounds, currentBounds: bounds),
      ),
    );
    return true;
  }
}

class _RectangleSelectGesture extends _SelectionGesture {
  _RectangleSelectGesture({
    required super.selection,
    required super.requestRepaint,
    required super.imageBounds,
    required ui.Offset start,
  }) : _start = start,
       _current = start;

  final ui.Offset _start;
  ui.Offset _current;
  ToolModifiers _modifiers = const ToolModifiers();

  ui.Rect get _rect => ShapeGeometry.rect(_start, _current, _modifiers);

  @override
  void update(ui.Offset point, ToolModifiers modifiers) {
    _current = point;
    _modifiers = modifiers;
    requestRepaint();
  }

  @override
  ui.Rect get bounds => _rect;

  @override
  ui.Path? buildPath() {
    final rect = _rect;
    if (rect.width < 1 || rect.height < 1) return null;
    return ui.Path()..addRect(rect);
  }

  @override
  void drawOverlay(ui.Canvas canvas, double zoom) {
    canvas.drawRect(
      _rect,
      ui.Paint()
        ..color = const ui.Color(0xCC000000)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1 / zoom,
    );
  }
}

class _FreeformSelectGesture extends _SelectionGesture {
  _FreeformSelectGesture({
    required super.selection,
    required super.requestRepaint,
    required super.imageBounds,
    required ui.Offset start,
  }) {
    _points.add(start);
  }

  final List<ui.Offset> _points = <ui.Offset>[];

  @override
  void update(ui.Offset point, ToolModifiers modifiers) {
    if (_points.isNotEmpty && (_points.last - point).distance < 1) return;
    _points.add(point);
    requestRepaint();
  }

  @override
  ui.Rect get bounds => buildPath()?.getBounds() ?? ui.Rect.zero;

  @override
  ui.Path? buildPath() {
    // Three points is the minimum that can enclose an area.
    if (_points.length < 3) return null;
    final path = ui.Path()..moveTo(_points.first.dx, _points.first.dy);
    for (var i = 1; i < _points.length; i++) {
      path.lineTo(_points[i].dx, _points[i].dy);
    }
    path.close();
    return path;
  }

  @override
  void drawOverlay(ui.Canvas canvas, double zoom) {
    if (_points.length < 2) return;
    final path = ui.Path()..moveTo(_points.first.dx, _points.first.dy);
    for (var i = 1; i < _points.length; i++) {
      path.lineTo(_points[i].dx, _points[i].dy);
    }
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = const ui.Color(0xCC000000)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1 / zoom,
    );
  }
}

/// Drags an existing selection, or one of its resize handles.
///
/// Not a [Tool]: it is started by the canvas when a press lands on a selection
/// that already exists, whichever selection tool happens to be active.
class SelectionDragGesture extends ToolGesture {
  SelectionDragGesture({
    required this.selection,
    required this.requestRepaint,
    required this.eraseColor,
    required this.handle,
    required ui.Offset start,
  }) : _last = start;

  final SelectionController selection;
  final VoidCallback requestRepaint;
  final ui.Color eraseColor;

  /// Null when the whole selection is being moved.
  final SelectionHandle? handle;

  ui.Offset _last;

  @override
  bool get modifiesBitmap => false;

  @override
  String get label => 'Move selection';

  @override
  void update(ui.Offset point, ToolModifiers modifiers) {
    final delta = point - _last;
    if (delta == ui.Offset.zero) return;
    _last = point;
    final target = handle;
    unawaited(
      target == null
          ? selection.moveBy(delta, eraseColor: eraseColor)
          : selection.resizeBy(target, delta, eraseColor: eraseColor),
    );
    requestRepaint();
  }

  @override
  bool release(ui.Offset point, ToolModifiers modifiers) {
    update(point, modifiers);
    return true;
  }

  @override
  void draw(ui.Canvas canvas) {}

  @override
  ui.Rect get bounds => selection.selection?.currentBounds ?? ui.Rect.zero;
}

class RectangleSelectTool extends Tool {
  const RectangleSelectTool();

  @override
  ToolId get id => ToolId.selectRectangle;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.selectionTransparent,
  };

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) {
    return _RectangleSelectGesture(
      selection: context.selection,
      requestRepaint: context.requestRepaint,
      imageBounds: context.document.bounds,
      start: point,
    );
  }
}

class FreeformSelectTool extends Tool {
  const FreeformSelectTool();

  @override
  ToolId get id => ToolId.selectFreeform;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.selectionTransparent,
  };

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) {
    return _FreeformSelectGesture(
      selection: context.selection,
      requestRepaint: context.requestRepaint,
      imageBounds: context.document.bounds,
      start: point,
    );
  }
}

/// Local fire-and-forget so selection updates, which are asynchronous because
/// lifting pixels goes through the engine, do not block the pointer handler.
void unawaited(Future<void> future) {
  future.catchError((Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'paint'),
    );
  });
}
