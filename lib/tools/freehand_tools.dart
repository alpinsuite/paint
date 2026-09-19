import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../model/tool_settings.dart';
import 'tool.dart';

/// A freehand stroke: pencil, brush and eraser all produce one of these and
/// differ only in how the stamp is shaped and composited.
class FreehandGesture extends ToolGesture {
  FreehandGesture({
    required this.label,
    required this.color,
    required this.width,
    required this.tip,
    required this.antiAlias,
    required this.blendMode,
    required this.snapToPixelGrid,
    required this.requestRepaint,
    required ui.Offset start,
  }) {
    _add(start);
  }

  @override
  final String label;

  final ui.Color color;
  final double width;
  final BrushTip tip;
  final bool antiAlias;
  final ui.BlendMode blendMode;

  /// True for the pencil, whose whole point is landing on exact pixels.
  final bool snapToPixelGrid;

  final VoidCallback requestRepaint;

  final List<ui.Offset> _points = <ui.Offset>[];

  double _minX = double.infinity;
  double _minY = double.infinity;
  double _maxX = double.negativeInfinity;
  double _maxY = double.negativeInfinity;

  void _add(ui.Offset raw) {
    final point = snapToPixelGrid
        ? ui.Offset(raw.dx.floorToDouble() + 0.5, raw.dy.floorToDouble() + 0.5)
        : raw;
    // Skip duplicates so a stationary pointer does not grow the path forever.
    if (_points.isNotEmpty && _points.last == point) return;
    _points.add(point);
    _minX = math.min(_minX, point.dx);
    _minY = math.min(_minY, point.dy);
    _maxX = math.max(_maxX, point.dx);
    _maxY = math.max(_maxY, point.dy);
  }

  @override
  void update(ui.Offset point, ToolModifiers modifiers) {
    _add(point);
    requestRepaint();
  }

  @override
  bool release(ui.Offset point, ToolModifiers modifiers) {
    _add(point);
    return true;
  }

  @override
  ui.Rect get bounds {
    if (_points.isEmpty) return ui.Rect.zero;
    // Inflate by the full width rather than half: slash tips extend to the
    // corner of their bounding box, which is further than half the width.
    return ui.Rect.fromLTRB(_minX, _minY, _maxX, _maxY).inflate(width + 1);
  }

  @override
  void draw(ui.Canvas canvas) {
    if (_points.isEmpty) return;

    final paint = ui.Paint()
      ..color = color
      ..blendMode = blendMode
      ..isAntiAlias = antiAlias;

    switch (tip) {
      case BrushTip.round:
      case BrushTip.square:
        paint
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = tip == BrushTip.round
              ? ui.StrokeCap.round
              : ui.StrokeCap.square
          ..strokeJoin = tip == BrushTip.round
              ? ui.StrokeJoin.round
              : ui.StrokeJoin.miter;
        if (_points.length == 1) {
          // A single click still has to leave a mark.
          final point = _points.first;
          if (tip == BrushTip.round) {
            canvas.drawCircle(
              point,
              width / 2,
              paint..style = ui.PaintingStyle.fill,
            );
          } else {
            canvas.drawRect(
              ui.Rect.fromCenter(center: point, width: width, height: width),
              paint..style = ui.PaintingStyle.fill,
            );
          }
          return;
        }
        final path = ui.Path()..moveTo(_points.first.dx, _points.first.dy);
        for (var i = 1; i < _points.length; i++) {
          path.lineTo(_points[i].dx, _points[i].dy);
        }
        canvas.drawPath(path, paint);

      case BrushTip.slashForward:
      case BrushTip.slashBackward:
        _drawSlashStroke(canvas, paint);
    }
  }

  /// Slash tips are a short angled bar dragged along the path, the way a
  /// calligraphy nib behaves. There is no stroke cap that does this, so the
  /// stamp is walked along the path by hand.
  void _drawSlashStroke(ui.Canvas canvas, ui.Paint paint) {
    paint
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = math.max(1, width / 4)
      ..strokeCap = ui.StrokeCap.butt;

    final half = width / 2;
    final direction = tip == BrushTip.slashForward
        ? const ui.Offset(1, -1)
        : const ui.Offset(1, 1);
    final arm = ui.Offset(
      direction.dx * half / math.sqrt2,
      direction.dy * half / math.sqrt2,
    );

    void stamp(ui.Offset at) {
      canvas.drawLine(at - arm, at + arm, paint);
    }

    if (_points.length == 1) {
      stamp(_points.first);
      return;
    }

    // Step along each segment at sub-pixel spacing so fast drags stay solid.
    const spacing = 0.5;
    for (var i = 1; i < _points.length; i++) {
      final from = _points[i - 1];
      final to = _points[i];
      final distance = (to - from).distance;
      final steps = math.max(1, (distance / spacing).ceil());
      for (var step = 0; step <= steps; step++) {
        stamp(ui.Offset.lerp(from, to, step / steps)!);
      }
    }
  }
}

/// One-pixel hard-edged freehand line.
class PencilTool extends Tool {
  const PencilTool();

  @override
  ToolId get id => ToolId.pencil;

  @override
  Set<ToolOption> get options => const <ToolOption>{};

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) {
    return FreehandGesture(
      label: 'Pencil',
      color: context.strokeColor,
      width: 1,
      tip: BrushTip.square,
      antiAlias: false,
      blendMode: ui.BlendMode.srcOver,
      snapToPixelGrid: true,
      requestRepaint: context.requestRepaint,
      start: point,
    );
  }
}

/// Variable-width freehand stroke with selectable tip shape.
class BrushTool extends Tool {
  const BrushTool();

  @override
  ToolId get id => ToolId.brush;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.size,
    ToolOption.tip,
    ToolOption.antiAlias,
  };

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) {
    final settings = context.settings;
    return FreehandGesture(
      label: 'Brush',
      color: context.strokeColor,
      width: settings.strokeWidth,
      tip: settings.brushTip,
      antiAlias: settings.antiAlias,
      blendMode: ui.BlendMode.srcOver,
      snapToPixelGrid: false,
      requestRepaint: context.requestRepaint,
      start: point,
    );
  }
}

/// Clears pixels to transparent, or paints the secondary colour when the
/// "erase to secondary colour" option is on — which is what classic Paint does.
class EraserTool extends Tool {
  const EraserTool();

  @override
  ToolId get id => ToolId.eraser;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.size,
    ToolOption.eraseToSecondary,
  };

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) {
    final settings = context.settings;
    final toSecondary = settings.eraseToSecondary;
    return FreehandGesture(
      label: 'Eraser',
      // Right-dragging the eraser in Paint restores the primary colour; here it
      // simply swaps which colour is painted, via ToolContext.
      color: toSecondary ? context.fillColor : const ui.Color(0xFF000000),
      width: math.max(2, settings.strokeWidth),
      tip: BrushTip.square,
      antiAlias: false,
      blendMode: toSecondary ? ui.BlendMode.srcOver : ui.BlendMode.clear,
      snapToPixelGrid: false,
      requestRepaint: context.requestRepaint,
      start: point,
    );
  }
}
