import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/canvas_controller.dart';
import '../controller/document_controller.dart';
import '../controller/selection_controller.dart';
import '../controller/update_controller.dart';
import '../controller/viewport_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_actions.dart';

/// Cursor position, image size and zoom, along the bottom edge.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentController>();
    final canvas = context.watch<CanvasController>();
    final viewport = context.watch<ViewportController>();
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final textStyle = theme.dimTextStyle;

    final cursor = canvas.cursorImagePosition;

    return Container(
      height: theme.metrics.barHeight,
      color: theme.palette.panel,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              cursor == null
                  ? ''
                  : l10n.statusPosition(cursor.dx.floor(), cursor.dy.floor()),
              style: textStyle,
            ),
          ),
          if (documents.isReady)
            Text(
              l10n.statusSize(
                documents.document.width,
                documents.document.height,
              ),
              style: textStyle,
            ),
          const Spacer(),
          SlateIconButton(
            icon: SlateIcons.minus,
            tooltip: l10n.actionZoomOut,
            size: 24,
            onPressed: viewport.zoomOut,
          ),
          SlateSlider(
            value: _zoomToSlider(viewport.zoom),
            min: 0,
            max: 1,
            width: 110,
            onChanged: (value) => viewport.zoomTo(_sliderToZoom(value)),
          ),
          SlateIconButton(
            icon: SlateIcons.plus,
            tooltip: l10n.actionZoomIn,
            size: 24,
            onPressed: viewport.zoomIn,
          ),
          SizedBox(
            width: 52,
            child: Text(
              l10n.statusZoom((viewport.zoom * 100).round()),
              style: textStyle,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 6),
          SlateIconButton(
            icon: SlateIcons.fitScreen,
            tooltip: l10n.actionZoomFit,
            size: 24,
            onPressed: viewport.fitToWindow,
          ),
          SlateIconButton(
            icon: SlateIcons.actualSize,
            tooltip: l10n.actionZoomNormal,
            size: 24,
            onPressed: viewport.zoomToActualSize,
          ),
          const SizedBox(width: 8),
          const SlateSeparator(vertical: true, inset: 7),
          const SizedBox(width: 8),
          const UpdateNotice(),
          const CopyToClipboardButton(),
        ],
      ),
    );
  }

  /// Slider position for [zoom], on a log scale.
  ///
  /// A linear slider would spend most of its travel above 100% and make the
  /// small zoom levels impossible to hit.
  static double _zoomToSlider(double zoom) {
    final clamped = zoom.clamp(
      ViewportController.minZoom,
      ViewportController.maxZoom,
    );
    final min = math.log(ViewportController.minZoom);
    final max = math.log(ViewportController.maxZoom);
    return ((math.log(clamped) - min) / (max - min)).clamp(0.0, 1.0);
  }

  static double _sliderToZoom(double slider) {
    final min = math.log(ViewportController.minZoom);
    final max = math.log(ViewportController.maxZoom);
    return math.exp(min + slider * (max - min));
  }
}

/// Puts the drawing on the system clipboard, ready to paste into a chat, a
/// document or anything else.
///
/// It sits in the corner rather than only in the Edit menu because the common
/// reason to open this editor at all is to sketch something quickly and paste
/// it somewhere; burying that behind a menu makes the fastest path the least
/// discoverable one. The work is delegated to [AppActions.copy], so the button,
/// the menu item and Ctrl+C are one implementation.
class CopyToClipboardButton extends StatefulWidget {
  const CopyToClipboardButton({super.key});

  /// How long the button stays in its confirming state.
  static const Duration confirmationDuration = Duration(seconds: 2);

  @override
  State<CopyToClipboardButton> createState() => _CopyToClipboardButtonState();
}

class _CopyToClipboardButtonState extends State<CopyToClipboardButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    final copied = await AppActions(context).copy();
    // A failed copy reports itself through a message; confirming here too would
    // contradict it.
    if (!mounted || !copied) return;
    // Confirming in place rather than with a snack bar: a snack bar would cover
    // this corner of the window, and the feedback belongs on the control that
    // was pressed.
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(CopyToClipboardButton.confirmationDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.slateColors;
    final hasSelection = context.watch<SelectionController>().hasSelection;

    return Tooltip(
      message: hasSelection ? l10n.copySelectionTooltip : l10n.copyImageTooltip,
      child: SlateButton(
        onPressed: _copy,
        icon: _copied ? SlateIcons.check : SlateIcons.copy,
        iconColor: _copied ? palette.accent : null,
        label: _copied ? l10n.copiedToClipboard : l10n.actionCopyToClipboard,
      ),
    );
  }
}

/// A quiet notice that a newer version has been published.
///
/// It offers the command rather than running it: Paint is installed by dpkg
/// into a root-owned directory, so upgrading is `apt`'s job and asking for a
/// password inside a drawing program would be the wrong shape entirely. One
/// click puts `sudo apt update && sudo apt upgrade` on the clipboard, which is
/// the shortest honest path from noticing to upgrading.
///
/// Nothing appears unless the user turned update checks on, so for everyone
/// else this widget is a zero-height nothing.
class UpdateNotice extends StatefulWidget {
  const UpdateNotice({super.key});

  /// How long the button stays in its confirming state.
  static const Duration confirmationDuration = Duration(seconds: 2);

  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copyCommand() async {
    await Clipboard.setData(
      const ClipboardData(text: UpdateController.upgradeCommand),
    );
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(UpdateNotice.confirmationDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<UpdateController>();
    final version = updates.availableVersion;
    if (version == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final palette = context.slateColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Tooltip(
          message: l10n.updateUpgradeHint,
          child: SlateButton(
            onPressed: _copyCommand,
            icon: _copied ? SlateIcons.check : SlateIcons.download,
            iconColor: palette.accent,
            label: _copied
                ? l10n.updateCommandCopied
                : l10n.updateAvailable(version),
          ),
        ),
        const SizedBox(width: 4),
        SlateIconButton(
          icon: SlateIcons.close,
          tooltip: l10n.updateDismiss,
          size: 22,
          onPressed: updates.dismiss,
        ),
        const SizedBox(width: 8),
        const SlateSeparator(vertical: true, inset: 7),
        const SizedBox(width: 8),
      ],
    );
  }
}
