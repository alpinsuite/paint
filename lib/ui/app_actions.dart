import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/canvas_controller.dart';
import '../controller/document_controller.dart';
import '../controller/selection_controller.dart';
import '../controller/update_controller.dart';
import '../controller/viewport_controller.dart';
import '../core/image_utils.dart';
import '../core/settings/settings_controller.dart';
import '../io/clipboard_service.dart';
import '../io/file_service.dart';
import '../io/update_check.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/selection.dart';
import '../model/tool_settings.dart';
import '../ops/transform_ops.dart';
import 'dialogs.dart';

/// Every user-facing command, in one place.
///
/// The menu bar, the keyboard shortcuts and the toolbar all call into this, so
/// a command behaves identically however it is invoked and there is exactly one
/// implementation to keep correct.
class AppActions {
  const AppActions(this.context);

  final BuildContext context;

  DocumentController get _documents => context.read<DocumentController>();

  SettingsController get _settings => context.read<SettingsController>();

  ToolSettings get _tools => context.read<ToolSettings>();

  ViewportController get _viewport => context.read<ViewportController>();

  CanvasController get _canvas => context.read<CanvasController>();

  SelectionController get _selections => context.read<SelectionController>();

  /// Transparent when "transparent selection" is on, so lifting leaves a hole
  /// rather than a block of the secondary colour.
  ui.Color get _eraseColor => _tools.selectionTransparent
      ? const ui.Color(0x00000000)
      : _tools.secondaryColor;

  FileService get _files => context.read<FileService>();

  AppLocalizations get _l10n => AppLocalizations.of(context);

  // ---------------------------------------------------------------- File

  Future<void> newImage() async {
    if (!await _confirmDiscardChanges()) return;
    if (!context.mounted) return;
    final spec = await showNewImageDialog(
      context,
      initialSize: _settings.defaultImageSize,
      secondaryColor: _tools.secondaryColor,
    );
    if (spec == null) return;
    await _documents.newDocument(
      width: spec.width,
      height: spec.height,
      background: spec.background,
    );
    await _settings.setDefaultImageSize(spec.width, spec.height);
  }

  Future<void> open() async {
    if (!await _confirmDiscardChanges()) return;
    final result = await _files.open();
    _reportFileResult(result);
  }

  Future<void> openPath(String path) async {
    if (!await _confirmDiscardChanges()) return;
    final result = await _files.openPath(path);
    _reportFileResult(result);
  }

  Future<void> save() async {
    final result = await _files.save();
    _reportFileResult(result);
  }

  Future<void> saveAs() async {
    final result = await _files.saveAs();
    _reportFileResult(result);
  }

  Future<void> copyTo() async {
    final result = await _files.copyTo();
    _reportFileResult(result);
  }

  Future<void> pasteFrom() async {
    final image = await _files.readImageForPaste();
    if (image == null) return;
    await _pasteImage(image);
  }

  /// Returns true when it is safe to throw away the current document.
  Future<bool> _confirmDiscardChanges() async {
    if (!_documents.isReady || !_documents.document.isModified) return true;
    final name = _documents.document.fileName ?? _l10n.untitledDocument;
    if (!context.mounted) return false;
    final choice = await showUnsavedChangesDialog(context, name);
    switch (choice) {
      case UnsavedChoice.cancel:
        return false;
      case UnsavedChoice.discard:
        return true;
      case UnsavedChoice.save:
        final result = await _files.save();
        _reportFileResult(result);
        return result is FileSucceeded;
    }
  }

  /// Exposed for the window close handler, which must ask before quitting.
  Future<bool> confirmClose() => _confirmDiscardChanges();

  // ---------------------------------------------------------------- Edit

  void undo() => _documents.undo();

  void redo() => _documents.redo();

  /// Copies the selection, or the whole image when there is none.
  ///
  /// Returns whether the clipboard actually took it, so callers can report a
  /// failure rather than implying a copy that did not happen.
  Future<bool> copy() async {
    if (!_documents.isReady) return false;

    var written = false;
    if (_selections.hasSelection) {
      final pixels = await _selections.extractPixels();
      if (pixels == null) return false;
      try {
        written = await ClipboardService.writeImage(pixels);
      } finally {
        pixels.dispose();
      }
    } else {
      written = await ClipboardService.writeImage(
        _documents.document.activeImage,
      );
    }

    if (!written) _showMessage(_l10n.errorClipboardWriteFailed);
    return written;
  }

  Future<void> cut() async {
    // Only remove the pixels once they are safely on the clipboard, or a failed
    // copy would destroy them.
    if (!await copy()) return;
    if (_selections.hasSelection) {
      await _selections.deleteSelection(eraseColor: _eraseColor);
      await _selections.deselect();
    } else {
      await clearImage();
    }
  }

  /// Clears the selected pixels, leaving the selection in place.
  Future<void> deleteSelection() async {
    if (!_selections.hasSelection) return;
    await _selections.deleteSelection(eraseColor: _eraseColor);
  }

  Future<void> selectAll() async {
    _tools.activeTool = ToolId.selectRectangle;
    await _selections.selectAll();
  }

  Future<void> deselect() => _selections.deselect();

  Future<void> invertSelection() => _selections.invert();

  Future<void> cropToSelection() => _selections.cropToSelection();

  /// Arrow-key nudge, one image pixel at a time.
  Future<void> nudgeSelection(ui.Offset delta) async {
    if (!_selections.hasSelection) return;
    await _selections.moveBy(delta, eraseColor: _eraseColor);
  }

  Future<void> paste() async {
    final image = await ClipboardService.readImage();
    if (image == null) {
      _showMessage(_l10n.errorClipboardEmpty);
      return;
    }
    await _pasteImage(image);
  }

  /// Pastes [image] as a floating selection at the top-left, growing the canvas
  /// first when the pasted image does not fit — the same thing Paint does.
  ///
  /// Floating rather than stamped means the paste can be dragged into place
  /// before it becomes part of the image, and Escape still leaves it where the
  /// user put it.
  Future<void> _pasteImage(ui.Image image) async {
    final document = _documents.document;
    if (image.width > document.width || image.height > document.height) {
      final width = image.width > document.width ? image.width : document.width;
      final height = image.height > document.height
          ? image.height
          : document.height;
      final background = _tools.secondaryColor;
      await _documents.commitCanvas(
        label: 'Grow canvas for paste',
        build: (source) => TransformOps.resizeCanvas(
          source,
          width,
          height,
          background: background,
        ),
      );
    }

    final rect = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    await _selections.replace(
      Selection(
        path: ui.Path()..addRect(rect),
        originalBounds: rect,
        currentBounds: rect,
        floating: image,
      ),
    );
    _tools.activeTool = ToolId.selectRectangle;
  }

  // --------------------------------------------------------------- Image

  Future<void> flipHorizontal() => _documents.commitCanvas(
    label: 'Flip horizontal',
    build: TransformOps.flipHorizontal,
  );

  Future<void> flipVertical() => _documents.commitCanvas(
    label: 'Flip vertical',
    build: TransformOps.flipVertical,
  );

  Future<void> rotate(int quarterTurns) => _documents.commitCanvas(
    label: 'Rotate',
    build: (source) => TransformOps.rotateQuarterTurns(source, quarterTurns),
  );

  Future<void> invertColors() => _documents.commitCanvas(
    label: 'Invert colors',
    build: TransformOps.invertColors,
  );

  Future<void> clearImage() {
    final background = _tools.secondaryColor;
    return _documents.commitCanvas(
      label: 'Clear image',
      build: (source) =>
          ImageUtils.filled(source.width, source.height, background),
    );
  }

  Future<void> resizeImage() async {
    final document = _documents.document;
    final spec = await showResizeDialog(
      context,
      currentWidth: document.width,
      currentHeight: document.height,
    );
    if (spec == null) return;
    await _documents.commitCanvas(
      label: 'Resize image',
      build: (source) => TransformOps.resize(
        source,
        spec.width,
        spec.height,
        smooth: spec.smooth,
      ),
    );
  }

  Future<void> canvasSize() async {
    final document = _documents.document;
    final spec = await showCanvasSizeDialog(
      context,
      currentWidth: document.width,
      currentHeight: document.height,
    );
    if (spec == null) return;
    final background = _tools.secondaryColor;
    await _documents.commitCanvas(
      label: 'Canvas size',
      build: (source) => TransformOps.resizeCanvas(
        source,
        spec.width,
        spec.height,
        anchor: spec.anchor,
        background: background,
      ),
    );
  }

  Future<void> stretchAndSkew() async {
    final spec = await showStretchSkewDialog(context);
    if (spec == null) return;
    final background = _tools.secondaryColor;
    await _documents.commitCanvas(
      label: 'Stretch and skew',
      build: (source) => TransformOps.stretchAndSkew(
        source,
        stretchX: spec.stretchX,
        stretchY: spec.stretchY,
        skewX: spec.skewX,
        skewY: spec.skewY,
        background: background,
      ),
    );
  }

  // ---------------------------------------------------------------- View

  void zoomIn() => _viewport.zoomIn();

  void zoomOut() => _viewport.zoomOut();

  void zoomActualSize() => _viewport.zoomToActualSize();

  void zoomFit() => _viewport.fitToWindow();

  Future<void> setThemeMode(ThemeMode mode) => _settings.setThemeMode(mode);

  // ---------------------------------------------------------------- Updates

  /// Asks the repository whether a newer version exists, because the user
  /// pressed the menu item. Reports all three outcomes: a version is waiting,
  /// nothing is, or the check could not be made — the last one matters, since
  /// silence after pressing a button reads as "up to date".
  Future<void> checkForUpdates() async {
    final updates = context.read<UpdateController>();
    // Both captured before the first await. This is invoked from a menu row,
    // and choosing it closes the menu — which unmounts the very context the
    // row was built with. Reaching for `context` afterwards finds a dead
    // element, so the answer would be computed and then quietly dropped.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = _l10n;

    void report(String message) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    report(l10n.updateChecking);
    try {
      final available = await updates.checkNow();
      report(
        available == null
            ? l10n.updateUpToDate
            : l10n.updateAvailable(available),
      );
    } on UpdateCheckFailure {
      report(l10n.updateCheckFailed);
    }
  }

  void selectTool(ToolId id) => _tools.activeTool = id;

  void cancelGesture() => _canvas.cancelGesture();

  /// Escape does the most local thing available: abandon the gesture in
  /// progress, and only drop the selection when there is no gesture to cancel.
  Future<void> cancelOrDeselect() async {
    if (_canvas.gesture != null) {
      _canvas.cancelGesture();
      return;
    }
    if (_canvas.textSession != null) {
      _canvas.cancelTextSession();
      return;
    }
    await _selections.deselect();
  }

  // ------------------------------------------------------------- Feedback

  void _reportFileResult(FileResult result) {
    switch (result) {
      case FileCancelled():
      case FileSucceeded():
        return;
      case FileFailed(:final kind, :final path):
        final name = path.split('/').last;
        _showMessage(switch (kind) {
          FileFailureKind.decode => _l10n.errorOpenFailed(name),
          FileFailureKind.io => _l10n.errorSaveFailed(name),
          FileFailureKind.encode => _l10n.errorSaveFailed(name),
          FileFailureKind.unsupportedFormat => _l10n.errorUnsupportedSaveFormat(
            path.contains('.') ? '.${path.split('.').last}' : path,
          ),
          FileFailureKind.tooLarge => _l10n.errorImageTooLarge(
            ImageUtils.maxDimension,
          ),
        });
    }
  }

  void _showMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
