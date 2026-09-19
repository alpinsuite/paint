import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../model/tool_settings.dart';
import 'tool.dart';

/// Builds the [TextPainter] used both by the on-canvas editor overlay and by
/// the commit, so what the user types is laid out exactly where it lands.
abstract final class TextRendering {
  static TextStyle styleFrom(ToolSettings settings, ui.Color color) {
    return TextStyle(
      color: Color(color.toARGB32()),
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize,
      fontWeight: settings.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: settings.italic ? FontStyle.italic : FontStyle.normal,
      decoration: settings.underline
          ? TextDecoration.underline
          : TextDecoration.none,
      // Underline colour follows the text; leaving it null renders black on a
      // light glyph colour in some font fallbacks.
      decorationColor: Color(color.toARGB32()),
    );
  }

  static TextPainter painterFor({
    required String text,
    required ToolSettings settings,
    required ui.Color color,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: styleFrom(settings, color)),
      textAlign: settings.textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    return painter;
  }
}

/// Places text on the image.
///
/// Pressing starts an editing session in the widget layer; the tool itself has
/// no gesture because text needs keyboard focus and IME support that a canvas
/// gesture cannot provide.
class TextTool extends Tool {
  const TextTool();

  @override
  ToolId get id => ToolId.text;

  @override
  Set<ToolOption> get options => const <ToolOption>{ToolOption.text};

  @override
  MouseCursor get cursor => SystemMouseCursors.text;

  @override
  ToolGesture? begin(ToolContext context, ui.Offset point) => null;

  @override
  Future<void> tap(ToolContext context, ui.Offset point) async {
    context.startTextSession(point);
  }
}
