import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../model/tool_settings.dart';
import 'tool.dart';

/// Paints shared by every shape tool.
///
/// The colour roles follow classic Paint: the outline is drawn in the colour of
/// the button being dragged, the interior in the other one.
class ShapeStyle {
  ShapeStyle({
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
    required this.fillStyle,
    required this.antiAlias,
  });

  factory ShapeStyle.from(ToolContext context) {
    return ShapeStyle(
      strokeColor: context.strokeColor,
      fillColor: context.fillColor,
      strokeWidth: context.settings.strokeWidth,
      fillStyle: context.settings.fillStyle,
      antiAlias: context.settings.antiAlias,
    );
  }

  final ui.Color strokeColor;
  final ui.Color fillColor;
  final double strokeWidth;
  final FillStyle fillStyle;
  final bool antiAlias;

  bool get hasFill => fillStyle != FillStyle.outline;

  bool get hasOutline => fillStyle != FillStyle.filled;

  ui.Paint get outlinePaint => ui.Paint()
    ..color = strokeColor
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeJoin = ui.StrokeJoin.miter
    ..isAntiAlias = antiAlias;

  ui.Paint get interiorPaint => ui.Paint()
    ..color = fillColor
    ..style = ui.PaintingStyle.fill
    ..isAntiAlias = antiAlias;

  /// How far the drawn shape can extend past its geometric bounds.
  double get overshoot => strokeWidth + 2;
}

/// Base for the tools that drag a shape between a press point and the cursor.
abstract class _DragGesture extends ToolGesture {
  _DragGesture({
    required this.style,
    required this.requestRepaint,
    required this.start,
    required this.modifiers,
  }) : current = start;

  final ShapeStyle style;
  final VoidCallback requestRepaint;

  /// Where the drag began, in image coordinates.
  final ui.Offset start;

  /// Where the pointer is now.
  ui.Offset current;

  ToolModifiers modifiers;

  @override
  void update(ui.Offset point, ToolModifiers modifiers) {
    current = point;
    this.modifiers = modifiers;
    requestRepaint();
  }

  @override
  bool release(ui.Offset point, ToolModifiers modifiers) {
    current = point;
    this.modifiers = modifiers;
    return true;
  }
}

/// Straight line. Shift snaps to 45° steps.
class LineGesture extends _DragGesture {
  LineGesture({
    required super.style,
    required super.requestRepaint,
    required super.start,
    required super.modifiers,
  });

  @override
  String get label => 'Line';

  ui.Offset get _end => ShapeGeometry.constrainAngle(start, current, modifiers);

  @override
  ui.Rect get bounds =>
      ShapeGeometry.padded(ui.Rect.fromPoints(start, _end), style.overshoot);

  @override
  void draw(ui.Canvas canvas) {
    canvas.drawLine(start, _end, style.outlinePaint);
  }
}

class LineTool extends Tool {
  const LineTool();

  @override
  ToolId get id => ToolId.line;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.size,
    ToolOption.antiAlias,
  };

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) => LineGesture(
    style: ShapeStyle.from(context),
    requestRepaint: context.requestRepaint,
    start: point,
    modifiers: context.modifiers,
  );
}

/// Rectangle, rounded rectangle and ellipse differ only in the shape drawn, so
/// they share one gesture.
enum ShapeKind { rectangle, roundedRectangle, ellipse }

class BoxGesture extends _DragGesture {
  BoxGesture({
    required this.shape,
    required this.cornerRadius,
    required super.style,
    required super.requestRepaint,
    required super.start,
    required super.modifiers,
  });

  final ShapeKind shape;
  final double cornerRadius;

  @override
  String get label => switch (shape) {
    ShapeKind.rectangle => 'Rectangle',
    ShapeKind.roundedRectangle => 'Rounded rectangle',
    ShapeKind.ellipse => 'Ellipse',
  };

  ui.Rect get _rect => ShapeGeometry.rect(start, current, modifiers);

  @override
  ui.Rect get bounds => ShapeGeometry.padded(_rect, style.overshoot);

  @override
  void draw(ui.Canvas canvas) {
    final rect = _rect;
    if (rect.isEmpty) return;

    void paintShape(ui.Paint paint) {
      switch (shape) {
        case ShapeKind.rectangle:
          canvas.drawRect(rect, paint);
        case ShapeKind.roundedRectangle:
          // Clamp so the radius never exceeds half the shorter side, which
          // would otherwise render as a lozenge with a distorted outline.
          final radius = math.min(
            cornerRadius,
            math.min(rect.width, rect.height) / 2,
          );
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)),
            paint,
          );
        case ShapeKind.ellipse:
          canvas.drawOval(rect, paint);
      }
    }

    if (style.hasFill) paintShape(style.interiorPaint);
    if (style.hasOutline) paintShape(style.outlinePaint);
  }
}

class RectangleTool extends Tool {
  const RectangleTool();

  @override
  ToolId get id => ToolId.rectangle;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.size,
    ToolOption.fillStyle,
    ToolOption.antiAlias,
  };

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) => BoxGesture(
    shape: ShapeKind.rectangle,
    cornerRadius: 0,
    style: ShapeStyle.from(context),
    requestRepaint: context.requestRepaint,
    start: point,
    modifiers: context.modifiers,
  );
}

class RoundedRectangleTool extends Tool {
  const RoundedRectangleTool();

  @override
  ToolId get id => ToolId.roundedRectangle;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.size,
    ToolOption.fillStyle,
    ToolOption.cornerRadius,
    ToolOption.antiAlias,
  };

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) => BoxGesture(
    shape: ShapeKind.roundedRectangle,
    cornerRadius: context.settings.cornerRadius,
    style: ShapeStyle.from(context),
    requestRepaint: context.requestRepaint,
    start: point,
    modifiers: context.modifiers,
  );
}

class EllipseTool extends Tool {
  const EllipseTool();

  @override
  ToolId get id => ToolId.ellipse;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.size,
    ToolOption.fillStyle,
    ToolOption.antiAlias,
  };

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) => BoxGesture(
    shape: ShapeKind.ellipse,
    cornerRadius: 0,
    style: ShapeStyle.from(context),
    requestRepaint: context.requestRepaint,
    start: point,
    modifiers: context.modifiers,
  );
}

/// Paint's curve tool: drag a straight line, then drag it into shape twice.
///
/// The two follow-up drags set the two control points of a cubic Bézier, in the
/// order the user pulls them.
class CurveGesture extends ToolGesture {
  CurveGesture({
    required this.style,
    required this.requestRepaint,
    required ui.Offset start,
  }) : _start = start,
       _end = start;

  final ShapeStyle style;
  final VoidCallback requestRepaint;

  final ui.Offset _start;
  ui.Offset _end;
  ui.Offset? _control1;
  ui.Offset? _control2;

  /// 0 = dragging the base line, 1 = first bend, 2 = second bend.
  int _stage = 0;

  @override
  String get label => 'Curve';

  @override
  void update(ui.Offset point, ToolModifiers modifiers) {
    switch (_stage) {
      case 0:
        _end = point;
      case 1:
        _control1 = point;
      default:
        _control2 = point;
    }
    requestRepaint();
  }

  @override
  bool release(ui.Offset point, ToolModifiers modifiers) {
    update(point, modifiers);
    _stage++;
    // Committed after both control points have been placed.
    return _stage > 2;
  }

  /// A curve that has been bent at least once is worth keeping; an untouched
  /// base line is committed as a plain line, matching Paint.
  @override
  bool cancel() => _stage > 0;

  ui.Path get _path {
    final path = ui.Path()..moveTo(_start.dx, _start.dy);
    final control1 = _control1;
    final control2 = _control2;
    if (control1 == null) {
      path.lineTo(_end.dx, _end.dy);
    } else {
      path.cubicTo(
        control1.dx,
        control1.dy,
        (control2 ?? control1).dx,
        (control2 ?? control1).dy,
        _end.dx,
        _end.dy,
      );
    }
    return path;
  }

  @override
  ui.Rect get bounds =>
      ShapeGeometry.padded(_path.getBounds(), style.overshoot);

  @override
  void draw(ui.Canvas canvas) {
    canvas.drawPath(_path, style.outlinePaint);
  }

  @override
  void drawOverlay(ui.Canvas canvas, double zoom) {
    if (_stage == 0) return;
    // Show where the control points sit so the second bend is predictable.
    final marker = ui.Paint()
      ..color = const ui.Color(0x99000000)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1 / zoom;
    for (final point in <ui.Offset?>[_control1, _control2]) {
      if (point == null) continue;
      canvas.drawCircle(point, 3 / zoom, marker);
    }
  }
}

class CurveTool extends Tool {
  const CurveTool();

  @override
  ToolId get id => ToolId.curve;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.size,
    ToolOption.antiAlias,
  };

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) => CurveGesture(
    style: ShapeStyle.from(context),
    requestRepaint: context.requestRepaint,
    start: point,
  );
}

/// Click to add vertices; click near the first vertex, or double-click, to
/// close the polygon.
class PolygonGesture extends ToolGesture {
  PolygonGesture({
    required this.style,
    required this.requestRepaint,
    required ui.Offset start,
  }) {
    _vertices.add(start);
    _cursor = start;
  }

  /// How close, in image pixels, a click must land to the first vertex to close
  /// the shape.
  static const double closeDistance = 6;

  final ShapeStyle style;
  final VoidCallback requestRepaint;

  final List<ui.Offset> _vertices = <ui.Offset>[];
  late ui.Offset _cursor;
  bool _closed = false;

  @override
  String get label => 'Polygon';

  @override
  void update(ui.Offset point, ToolModifiers modifiers) {
    _cursor = ShapeGeometry.constrainAngle(_vertices.last, point, modifiers);
    requestRepaint();
  }

  @override
  bool release(ui.Offset point, ToolModifiers modifiers) {
    final vertex = ShapeGeometry.constrainAngle(
      _vertices.last,
      point,
      modifiers,
    );
    if (_vertices.length > 1 &&
        (vertex - _vertices.first).distance <= closeDistance) {
      _closed = true;
      return true;
    }
    _vertices.add(vertex);
    _cursor = vertex;
    requestRepaint();
    return false;
  }

  /// Escape or a tool switch closes the polygon on what has been drawn so far,
  /// as long as it is more than a single point.
  @override
  bool cancel() {
    if (_vertices.length < 2) return false;
    _closed = true;
    return true;
  }

  ui.Path _buildPath({required bool includeCursor}) {
    final path = ui.Path()..moveTo(_vertices.first.dx, _vertices.first.dy);
    for (var i = 1; i < _vertices.length; i++) {
      path.lineTo(_vertices[i].dx, _vertices[i].dy);
    }
    if (includeCursor && !_closed) {
      path.lineTo(_cursor.dx, _cursor.dy);
    }
    if (_closed) path.close();
    return path;
  }

  @override
  ui.Rect get bounds => ShapeGeometry.padded(
    _buildPath(includeCursor: true).getBounds(),
    style.overshoot,
  );

  @override
  void draw(ui.Canvas canvas) {
    final path = _buildPath(includeCursor: !_closed);
    if (_closed && style.hasFill) {
      canvas.drawPath(path, style.interiorPaint);
    }
    if (!_closed || style.hasOutline) {
      canvas.drawPath(path, style.outlinePaint);
    }
  }

  @override
  void drawOverlay(ui.Canvas canvas, double zoom) {
    if (_closed || _vertices.length < 2) return;
    // Highlight the closing target so it is obvious where to click to finish.
    canvas.drawCircle(
      _vertices.first,
      closeDistance / 2,
      ui.Paint()
        ..color = const ui.Color(0xAA2196F3)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1 / zoom,
    );
  }
}

class PolygonTool extends Tool {
  const PolygonTool();

  @override
  ToolId get id => ToolId.polygon;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.size,
    ToolOption.fillStyle,
    ToolOption.antiAlias,
  };

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) => PolygonGesture(
    style: ShapeStyle.from(context),
    requestRepaint: context.requestRepaint,
    start: point,
  );
}
