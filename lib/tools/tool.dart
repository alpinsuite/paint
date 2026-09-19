import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../controller/document_controller.dart';
import '../controller/selection_controller.dart';
import '../model/paint_document.dart';
import '../model/tool_settings.dart';

/// Everything a tool needs for one gesture.
class ToolContext {
  ToolContext({
    required this.settings,
    required this.document,
    required this.controller,
    required this.selection,
    required this.modifiers,
    required this.requestRepaint,
    required this.pickColor,
    required this.startTextSession,
  });

  final ToolSettings settings;
  final PaintDocument document;

  /// For the tools that rewrite pixels directly instead of drawing a gesture —
  /// the fill bucket in particular.
  final DocumentController controller;

  /// For the selection tools, which change editing state rather than pixels.
  final SelectionController selection;

  final ToolModifiers modifiers;

  /// Asks the canvas to repaint the live preview.
  final VoidCallback requestRepaint;

  /// Sets the primary (or, for a right-drag, secondary) colour. Used by the
  /// eyedropper.
  final void Function(Color color, {required bool secondary}) pickColor;

  /// Opens the in-canvas text editor at the given image position. Text needs
  /// real keyboard focus and an IME, so it lives in the widget layer rather
  /// than in a [ToolGesture].
  final void Function(ui.Offset at) startTextSession;

  /// Colour the gesture draws with. Right-dragging swaps primary and secondary,
  /// which is how Paint has always worked.
  Color get strokeColor => modifiers.secondaryButton
      ? settings.secondaryColor
      : settings.primaryColor;

  /// Colour shape interiors are filled with.
  Color get fillColor => modifiers.secondaryButton
      ? settings.primaryColor
      : settings.secondaryColor;

  ui.Size get imageSize => document.size;
}

/// One in-progress tool gesture.
///
/// [draw] is called both to render the live preview every frame and once more
/// when the gesture is committed to the bitmap. Sharing that single method is
/// what guarantees the committed result matches what the user was shown while
/// dragging.
abstract class ToolGesture {
  /// Undo label for the change this gesture will make.
  String get label;

  /// False for gestures that do not paint — the selection tools define a
  /// region instead, and must not push an entry onto the undo stack.
  bool get modifiesBitmap => true;

  /// Pointer moved to [point], in image coordinates.
  void update(ui.Offset point, ToolModifiers modifiers);

  /// Pointer released at [point].
  ///
  /// Returns true when the gesture is complete and should be committed, false
  /// when the tool wants more input — polygon and curve both collect several
  /// clicks before they finish.
  bool release(ui.Offset point, ToolModifiers modifiers);

  /// Called when the user presses Escape or switches tool mid-gesture.
  ///
  /// Returns true if the partial gesture should still be committed. Most tools
  /// discard it.
  bool cancel() => false;

  /// Draws the gesture in image coordinates.
  void draw(ui.Canvas canvas);

  /// The region [draw] touches, in image coordinates. Undo only preserves the
  /// pixels inside it, and the commit clips to it, so it must not be tighter
  /// than what [draw] actually paints.
  ui.Rect get bounds;

  /// Extra chrome drawn over the preview but never committed — rubber-band
  /// outlines, control points, the text caret. [zoom] lets the overlay keep a
  /// constant on-screen thickness.
  void drawOverlay(ui.Canvas canvas, double zoom) {}
}

/// A drawing tool.
///
/// Tools are stateless and shared; all per-gesture state lives in the
/// [ToolGesture] returned by [begin].
abstract class Tool {
  const Tool();

  ToolId get id;

  /// Options the options bar shows while this tool is active.
  Set<ToolOption> get options;

  MouseCursor get cursor => SystemMouseCursors.precise;

  /// Starts a gesture at [point], or returns null for a tool that acts
  /// immediately on press — in which case [tap] is called instead.
  ToolGesture? begin(ToolContext context, ui.Offset point);

  /// Acts immediately at [point]. Only called when [begin] returns null.
  Future<void> tap(ToolContext context, ui.Offset point) async {}
}

/// Geometry helpers shared by the tools that drag a shape between two points.
abstract final class ShapeGeometry {
  /// The rectangle between [start] and [end], honouring Shift (constrain to a
  /// square) and Ctrl (draw outwards from [start] as the centre).
  static ui.Rect rect(ui.Offset start, ui.Offset end, ToolModifiers modifiers) {
    var corner = end;
    if (modifiers.shift) {
      final delta = corner - start;
      final side = math.max(delta.dx.abs(), delta.dy.abs());
      corner = ui.Offset(
        start.dx + (delta.dx.isNegative ? -side : side),
        start.dy + (delta.dy.isNegative ? -side : side),
      );
    }
    if (modifiers.control) {
      final delta = corner - start;
      return ui.Rect.fromCenter(
        center: start,
        width: delta.dx.abs() * 2,
        height: delta.dy.abs() * 2,
      );
    }
    return ui.Rect.fromPoints(start, corner);
  }

  /// [end] snapped to 45° increments around [start] when Shift is held.
  static ui.Offset constrainAngle(
    ui.Offset start,
    ui.Offset end,
    ToolModifiers modifiers,
  ) {
    if (!modifiers.shift) return end;
    final delta = end - start;
    if (delta == ui.Offset.zero) return end;
    const step = math.pi / 4;
    final angle = (delta.direction / step).roundToDouble() * step;
    final length = delta.distance;
    return start +
        ui.Offset(length * math.cos(angle), length * math.sin(angle));
  }

  /// Grows [rect] by [padding] and normalises it, so a zero-area drag still
  /// yields a committable region.
  static ui.Rect padded(ui.Rect rect, double padding) {
    final normalised = ui.Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(rect.left, rect.right),
      math.max(rect.top, rect.bottom),
    );
    return normalised.inflate(padding);
  }
}
