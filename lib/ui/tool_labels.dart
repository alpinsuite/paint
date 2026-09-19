import '../l10n/generated/app_localizations.dart';
import '../model/tool_settings.dart';

/// Localised name of a tool.
///
/// Shared by the palette tooltips, the options bar heading and the status bar
/// so the three can never drift apart.
String toolLabel(AppLocalizations l10n, ToolId id) => switch (id) {
  ToolId.pencil => l10n.toolPencil,
  ToolId.brush => l10n.toolBrush,
  ToolId.eraser => l10n.toolEraser,
  ToolId.fill => l10n.toolFill,
  ToolId.eyedropper => l10n.toolEyedropper,
  ToolId.text => l10n.toolText,
  ToolId.line => l10n.toolLine,
  ToolId.curve => l10n.toolCurve,
  ToolId.rectangle => l10n.toolRectangle,
  ToolId.roundedRectangle => l10n.toolRoundedRectangle,
  ToolId.ellipse => l10n.toolEllipse,
  ToolId.polygon => l10n.toolPolygon,
  ToolId.selectRectangle => l10n.toolSelectRectangle,
  ToolId.selectFreeform => l10n.toolSelectFreeform,
};
