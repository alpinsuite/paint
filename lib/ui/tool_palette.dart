import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/tool_settings.dart';
import '../tools/tool_registry.dart';
import 'tool_labels.dart';

/// The vertical tool strip down the left edge.
class ToolPalette extends StatelessWidget {
  const ToolPalette({super.key});

  /// Two columns, like Paint's palette — narrow enough to leave the canvas the
  /// window, wide enough that the icons stay legible.
  static const int columns = 2;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ToolSettings>();

    return Container(
      width: AppTheme.toolButtonSize * columns + 12,
      color: context.slateColors.panel,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 1,
          runSpacing: 1,
          children: <Widget>[
            for (final tool in ToolRegistry.tools)
              _ToolButton(
                toolId: tool.id,
                selected: settings.activeTool == tool.id,
                onPressed: () => settings.activeTool = tool.id,
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  const _ToolButton({
    required this.toolId,
    required this.selected,
    required this.onPressed,
  });

  final ToolId toolId;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    final label = toolLabel(AppLocalizations.of(context), widget.toolId);

    return Tooltip(
      message: '$label  (${ToolRegistry.shortcutFor(widget.toolId)})',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Semantics(
            label: label,
            selected: widget.selected,
            button: true,
            child: Container(
              width: AppTheme.toolButtonSize,
              height: AppTheme.toolButtonSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.selected
                    ? theme.palette.selected
                    : _hover
                    ? theme.palette.hover
                    : const Color(0x00000000),
                borderRadius: BorderRadius.circular(theme.metrics.radius),
              ),
              child: Icon(
                ToolRegistry.iconFor(widget.toolId),
                size: 17,
                color: widget.selected
                    ? theme.palette.accent
                    : theme.palette.inkDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
