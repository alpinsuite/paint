import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/image_utils.dart';
import '../model/tool_settings.dart';
import '../ops/flood_fill.dart';
import 'tool.dart';

/// Fills the region of similarly-coloured pixels under the cursor.
///
/// Acts on press with no drag gesture, so it rewrites the bitmap through
/// [DocumentController.commitCanvas] rather than producing a [ToolGesture].
class FillTool extends Tool {
  const FillTool();

  @override
  ToolId get id => ToolId.fill;

  @override
  Set<ToolOption> get options => const <ToolOption>{
    ToolOption.tolerance,
    ToolOption.contiguous,
  };

  @override
  MouseCursor get cursor => SystemMouseCursors.click;

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) => null;

  @override
  Future<void> tap(ToolContext context, ui.Offset point) async {
    final x = point.dx.floor();
    final y = point.dy.floor();
    final document = context.document;
    if (x < 0 || y < 0 || x >= document.width || y >= document.height) return;

    final color = context.strokeColor;
    final settings = context.settings;

    await context.controller.commitCanvas(
      label: 'Fill',
      build: (source) async {
        final pixels = await ImageUtils.toStraightRgbaBytes(source);
        final result = await floodFill(
          FloodFillRequest(
            pixels: pixels,
            width: source.width,
            height: source.height,
            startX: x,
            startY: y,
            fillR: (color.r * 255).round(),
            fillG: (color.g * 255).round(),
            fillB: (color.b * 255).round(),
            fillA: (color.a * 255).round(),
            tolerance: settings.tolerance,
            contiguous: settings.contiguous,
          ),
        );
        // Returning the source unchanged tells commitCanvas to skip the undo
        // entry, so clicking an already-filled area is a true no-op.
        if (!result.changed) return source;
        return ImageUtils.fromStraightRgbaBytes(
          result.pixels,
          source.width,
          source.height,
        );
      },
    );
  }
}

/// Picks the colour under the cursor into the primary (or, on right-click,
/// secondary) swatch.
class EyedropperTool extends Tool {
  const EyedropperTool();

  @override
  ToolId get id => ToolId.eyedropper;

  @override
  Set<ToolOption> get options => const <ToolOption>{};

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) => null;

  @override
  Future<void> tap(ToolContext context, ui.Offset point) async {
    final x = point.dx.floor();
    final y = point.dy.floor();
    final document = context.document;
    if (x < 0 || y < 0 || x >= document.width || y >= document.height) return;

    // Crop to the single pixel before reading it back: pulling the whole
    // bitmap across just to sample one pixel would stall on a large image.
    final pixel = await ImageUtils.extractRegion(
      document.activeImage,
      ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
    );
    try {
      final bytes = await ImageUtils.toStraightRgbaBytes(pixel);
      context.pickColor(
        Color.fromARGB(bytes[3], bytes[0], bytes[1], bytes[2]),
        secondary: context.modifiers.secondaryButton,
      );
    } finally {
      pixel.dispose();
    }
  }
}
