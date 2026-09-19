import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../controller/viewport_controller.dart';
import '../core/theme/app_theme.dart';
import '../model/paint_document.dart';
import '../model/selection.dart';
import '../tools/tool.dart';

/// Draws the document, the transparency checkerboard and the live tool preview.
class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.document,
    required this.viewport,
    required this.gesture,
    required this.selection,
    required this.colors,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// Size of one checkerboard square on screen. Fixed in screen space so the
  /// pattern reads as "behind the image" rather than as image content.
  static const double checkerSize = 8;

  /// Ceiling on dashes per selection outline.
  ///
  /// The dash length is expressed in image units so the dashes keep a constant
  /// on-screen size, which means a long outline at high zoom would otherwise
  /// generate tens of thousands of sub-paths every frame. Past this many, the
  /// dashes simply grow.
  static const int maxDashesPerContour = 400;

  final PaintDocument document;
  final ViewportController viewport;
  final ToolGesture? gesture;
  final Selection? selection;
  final CanvasColors colors;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // CustomPaint does not clip to its own box, and the image rectangle grows
    // with the zoom: at 6400% it is tens of thousands of pixels across, so
    // without this the canvas paints straight over the menu bar, the tool
    // palette and the colour panel and swallows their clicks.
    canvas.clipRect(ui.Offset.zero & size);

    canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = colors.backdrop);

    final imageRect = viewport.imageScreenRect;
    if (imageRect.isEmpty) return;

    _paintCheckerboard(canvas, imageRect, size);

    final zoom = viewport.zoom;
    // Crisp pixels once magnified — a paint program that blurs at 800% is
    // unusable for touching up individual pixels.
    final filterQuality = zoom >= 1
        ? ui.FilterQuality.none
        : ui.FilterQuality.medium;

    canvas.save();
    canvas.clipRect(imageRect);
    canvas.translate(viewport.origin.dx, viewport.origin.dy);
    canvas.scale(zoom);

    final documentRect = document.bounds;
    // The layer isolates the preview so an eraser stroke, which composites with
    // BlendMode.clear, punches through the image instead of the checkerboard.
    canvas.saveLayer(documentRect, ui.Paint());
    for (final layer in document.layers) {
      if (!layer.visible) continue;
      canvas.drawImage(
        layer.image,
        ui.Offset.zero,
        ui.Paint()
          ..filterQuality = filterQuality
          ..color = ui.Color.fromRGBO(0, 0, 0, layer.opacity),
      );
    }
    gesture?.draw(canvas);
    _paintFloatingSelection(canvas);
    canvas.restore();

    // Overlays are chrome, not pixels: outside the layer so they are never
    // affected by the preview's blend mode and never end up committed.
    gesture?.drawOverlay(canvas, zoom);
    _paintSelectionOutline(canvas, zoom);

    canvas.restore();

    canvas.drawRect(
      imageRect.deflate(0.5),
      ui.Paint()
        ..color = colors.canvasBorder
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// Lifted selection pixels, drawn wherever the selection has been dragged to.
  void _paintFloatingSelection(ui.Canvas canvas) {
    final current = selection;
    final floating = current?.floating;
    if (current == null || floating == null) return;
    canvas.drawImageRect(
      floating,
      ui.Rect.fromLTWH(
        0,
        0,
        floating.width.toDouble(),
        floating.height.toDouble(),
      ),
      current.currentBounds,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  /// Marching ants plus resize handles.
  ///
  /// The outline is drawn twice — a dark dashed line over a light solid one —
  /// so it stays visible over both light and dark image content.
  void _paintSelectionOutline(ui.Canvas canvas, double zoom) {
    final current = selection;
    if (current == null || current.isEmpty) return;

    final path = current.transformedPath;
    final width = 1 / zoom;

    canvas.drawPath(
      path,
      ui.Paint()
        ..color = colors.marchingAntsLight
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = width * 2,
    );
    canvas.drawPath(
      _dashed(path, 4 / zoom),
      ui.Paint()
        ..color = colors.marchingAntsDark
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = width * 2,
    );

    final handleSize = 7 / zoom;
    final bounds = current.currentBounds;
    for (final handle in SelectionHandle.values) {
      final centre = ui.Offset(
        bounds.left + bounds.width * handle.anchor.dx,
        bounds.top + bounds.height * handle.anchor.dy,
      );
      final rect = ui.Rect.fromCenter(
        center: centre,
        width: handleSize,
        height: handleSize,
      );
      canvas.drawRect(rect, ui.Paint()..color = colors.handleFill);
      canvas.drawRect(
        rect,
        ui.Paint()
          ..color = colors.handleBorder
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }
  }

  /// Splits [source] into dashes of [dashLength], leaving equal gaps.
  static ui.Path _dashed(ui.Path source, double dashLength) {
    final result = ui.Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      final step = math.max(dashLength, metric.length / maxDashesPerContour);
      while (distance < metric.length) {
        final next = distance + step;
        if (draw) {
          result.addPath(
            metric.extractPath(distance, next.clamp(0, metric.length)),
            ui.Offset.zero,
          );
        }
        distance = next;
        draw = !draw;
      }
    }
    return result;
  }

  void _paintCheckerboard(ui.Canvas canvas, ui.Rect imageRect, ui.Size size) {
    // Only the part actually on screen is worth drawing. Iterating the whole
    // image rectangle costs millions of squares once zoomed in — a 640x440
    // image at 6400% spans 40960x28160 logical pixels, which is about nine
    // million squares per frame and freezes the window.
    final visible = imageRect.intersect(ui.Offset.zero & size);
    if (visible.isEmpty) return;

    canvas.save();
    canvas.clipRect(visible);
    canvas.drawRect(visible, ui.Paint()..color = colors.checkerLight);

    final dark = ui.Paint()..color = colors.checkerDark;
    const period = checkerSize * 2;

    // Phase the pattern on the image origin rather than on the visible area,
    // so the squares stay put instead of crawling while panning.
    final phaseX = viewport.origin.dx;
    final phaseY = viewport.origin.dy;
    final startX = visible.left - (visible.left - phaseX) % period;
    final startY = visible.top - (visible.top - phaseY) % period;

    for (var y = startY; y < visible.bottom; y += checkerSize) {
      final rowOdd = (((y - phaseY) / checkerSize).round() % 2) == 1;
      for (
        var x = startX + (rowOdd ? checkerSize : 0);
        x < visible.right;
        x += period
      ) {
        canvas.drawRect(ui.Rect.fromLTWH(x, y, checkerSize, checkerSize), dark);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.gesture != gesture ||
        oldDelegate.selection != selection ||
        oldDelegate.colors != colors;
  }
}
