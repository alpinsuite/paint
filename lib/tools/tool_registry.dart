import 'package:flutter/material.dart';

import '../model/tool_settings.dart';
import 'freehand_tools.dart';
import 'pixel_tools.dart';
import 'selection_tools.dart';
import 'shape_tools.dart';
import 'text_tool.dart';
import 'tool.dart';

/// The tool palette, in the order it is shown.
///
/// Grouping follows classic Paint: selection first, then the freehand tools,
/// then the pixel tools, then the shapes.
abstract final class ToolRegistry {
  static const List<Tool> tools = <Tool>[
    RectangleSelectTool(),
    FreeformSelectTool(),
    PencilTool(),
    BrushTool(),
    EraserTool(),
    FillTool(),
    EyedropperTool(),
    TextTool(),
    LineTool(),
    CurveTool(),
    RectangleTool(),
    RoundedRectangleTool(),
    EllipseTool(),
    PolygonTool(),
  ];

  static final Map<ToolId, Tool> _byId = <ToolId, Tool>{
    for (final tool in tools) tool.id: tool,
  };

  static Tool? byId(ToolId id) => _byId[id];

  /// Icon for the palette button.
  static IconData iconFor(ToolId id) => switch (id) {
    ToolId.pencil => Icons.edit_outlined,
    ToolId.brush => Icons.brush_outlined,
    ToolId.eraser => Icons.cleaning_services_outlined,
    ToolId.fill => Icons.format_color_fill_outlined,
    ToolId.eyedropper => Icons.colorize_outlined,
    ToolId.text => Icons.title,
    ToolId.line => Icons.show_chart,
    ToolId.curve => Icons.gesture,
    ToolId.rectangle => Icons.crop_square,
    ToolId.roundedRectangle => Icons.rounded_corner,
    ToolId.ellipse => Icons.circle_outlined,
    ToolId.polygon => Icons.pentagon_outlined,
    ToolId.selectRectangle => Icons.crop_din,
    ToolId.selectFreeform => Icons.highlight_alt_outlined,
  };

  /// Single-key shortcut, matching the letters Paint users already know where
  /// they do not clash.
  static String shortcutFor(ToolId id) => switch (id) {
    ToolId.pencil => 'P',
    ToolId.brush => 'B',
    ToolId.eraser => 'E',
    ToolId.fill => 'F',
    ToolId.eyedropper => 'K',
    ToolId.text => 'T',
    ToolId.line => 'L',
    ToolId.curve => 'C',
    ToolId.rectangle => 'R',
    ToolId.roundedRectangle => 'D',
    ToolId.ellipse => 'O',
    ToolId.polygon => 'G',
    ToolId.selectRectangle => 'S',
    ToolId.selectFreeform => 'A',
  };
}
