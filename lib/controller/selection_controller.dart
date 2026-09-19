import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/image_utils.dart';
import '../model/selection.dart';
import 'document_controller.dart';

/// Owns the current selection and everything that can be done to it.
///
/// Kept separate from [DocumentController] so the document stays a pure
/// bitmap-plus-history: a selection is a transient editing state that must not
/// end up on the undo stack until it is actually stamped down.
class SelectionController extends ChangeNotifier {
  SelectionController({required this.documents});

  final DocumentController documents;

  Selection? _selection;

  Selection? get selection => _selection;

  bool get hasSelection => _selection != null && !_selection!.isEmpty;

  /// Replaces the selection, anchoring whatever was floating first so its
  /// pixels are not lost.
  Future<void> replace(Selection? next) async {
    if (_selection?.isFloating ?? false) {
      await anchor();
    }
    _selection?.dispose();
    _selection = next;
    notifyListeners();
  }

  /// Drops the selection, stamping down any floating pixels.
  Future<void> deselect() async {
    if (_selection == null) return;
    if (_selection!.isFloating) await anchor();
    _selection?.dispose();
    _selection = null;
    notifyListeners();
  }

  /// Selects the whole image.
  Future<void> selectAll() async {
    await replace(Selection.rectangle(documents.document.bounds));
  }

  /// Inverts the selection within the image bounds.
  Future<void> invert() async {
    final current = _selection;
    if (current == null) {
      await selectAll();
      return;
    }
    if (current.isFloating) await anchor();
    final bounds = documents.document.bounds;
    final inverted = ui.Path.combine(
      ui.PathOperation.difference,
      ui.Path()..addRect(bounds),
      current.transformedPath,
    );
    await replace(
      Selection(
        path: inverted,
        originalBounds: inverted.getBounds(),
        currentBounds: inverted.getBounds(),
      ),
    );
  }

  /// Moves the selection by [delta], lifting it out of the layer first.
  Future<void> moveBy(ui.Offset delta, {required ui.Color eraseColor}) async {
    final current = _selection;
    if (current == null) return;
    final lifted = await _ensureFloating(eraseColor: eraseColor);
    if (lifted == null) return;
    _selection = lifted.movedBy(delta);
    notifyListeners();
  }

  /// Resizes the selection by dragging [handle] by [delta].
  Future<void> resizeBy(
    SelectionHandle handle,
    ui.Offset delta, {
    required ui.Color eraseColor,
  }) async {
    final current = _selection;
    if (current == null) return;
    final lifted = await _ensureFloating(eraseColor: eraseColor);
    if (lifted == null) return;
    _selection = lifted.resized(handle, delta);
    notifyListeners();
  }

  /// Lifts the selected pixels out of the layer if they are not already
  /// floating, erasing the region they came from.
  ///
  /// [eraseColor] is transparent for a transparent selection and the secondary
  /// colour otherwise, matching Paint's transparent/opaque selection toggle.
  Future<Selection?> _ensureFloating({required ui.Color eraseColor}) async {
    final current = _selection;
    if (current == null) return null;
    if (current.isFloating) return current;

    final pixels = await extractPixels();
    if (pixels == null) return current;

    await _eraseRegion(current, eraseColor);

    final floated = current.copyWith(floating: pixels);
    _selection = floated;
    return floated;
  }

  /// A copy of the selected pixels, masked to the selection shape.
  ///
  /// The caller owns the returned image.
  Future<ui.Image?> extractPixels() async {
    final current = _selection;
    if (current == null || current.isEmpty) return null;

    final floating = current.floating;
    if (floating != null) {
      return ImageUtils.drawOver(floating, (_) {});
    }

    final bounds = ImageUtils.clampToImage(
      current.originalBounds,
      documents.document.width,
      documents.document.height,
    );
    if (bounds == null) return null;

    final source = documents.document.activeImage;
    return ImageUtils.rasterize(
      width: bounds.width.round(),
      height: bounds.height.round(),
      draw: (canvas) {
        canvas.translate(-bounds.left, -bounds.top);
        // Clipping to the selection path is what makes a free-form selection
        // carry its actual shape instead of its bounding box.
        canvas.clipPath(current.path);
        canvas.drawImage(
          source,
          ui.Offset.zero,
          ui.Paint()..blendMode = ui.BlendMode.src,
        );
      },
    );
  }

  /// Stamps floating pixels back into the layer at their current position.
  Future<void> anchor() async {
    final current = _selection;
    if (current == null) return;
    final floating = current.floating;
    if (floating == null) return;

    final destination = current.currentBounds;
    await documents.commitRegion(
      label: 'Move selection',
      bounds: destination.inflate(1),
      draw: (canvas) {
        canvas.drawImageRect(
          floating,
          ui.Rect.fromLTWH(
            0,
            0,
            floating.width.toDouble(),
            floating.height.toDouble(),
          ),
          destination,
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
      },
    );

    _selection = Selection(
      path: current.transformedPath,
      originalBounds: destination,
      currentBounds: destination,
    );
    floating.dispose();
    notifyListeners();
  }

  /// Clears the selected pixels — Delete, and the second half of Cut.
  Future<void> deleteSelection({required ui.Color eraseColor}) async {
    final current = _selection;
    if (current == null) return;
    if (current.isFloating) {
      // Floating pixels were already erased from the layer when they were
      // lifted, so dropping them is enough.
      current.floating!.dispose();
      _selection = Selection(
        path: current.path,
        originalBounds: current.originalBounds,
        currentBounds: current.currentBounds,
      );
      notifyListeners();
      return;
    }
    await _eraseRegion(current, eraseColor);
  }

  Future<void> _eraseRegion(Selection selection, ui.Color eraseColor) {
    final path = selection.path;
    return documents.commitRegion(
      label: 'Clear selection',
      bounds: selection.originalBounds.inflate(1),
      draw: (canvas) {
        canvas.save();
        canvas.clipPath(path);
        // BlendMode.src writes the colour including its alpha, so a fully
        // transparent erase colour genuinely clears rather than painting
        // transparent black over the existing pixels.
        canvas.drawColor(eraseColor, ui.BlendMode.src);
        canvas.restore();
      },
    );
  }

  /// Crops the image down to the selection.
  Future<void> cropToSelection() async {
    final current = _selection;
    if (current == null || current.isEmpty) return;
    if (current.isFloating) await anchor();

    final rect = ImageUtils.clampToImage(
      _selection!.currentBounds,
      documents.document.width,
      documents.document.height,
    );
    if (rect == null) return;

    await documents.commitCanvas(
      label: 'Crop to selection',
      build: (source) => ImageUtils.extractRegion(source, rect),
    );
    await deselect();
  }

  @override
  void dispose() {
    _selection?.dispose();
    super.dispose();
  }
}
