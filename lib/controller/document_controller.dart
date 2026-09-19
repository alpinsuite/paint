import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/image_utils.dart';
import '../model/paint_document.dart';
import 'history.dart';

/// Owns the document being edited and is the only place that mutates it.
///
/// Every edit funnels through [commitRegion] or [commitCanvas], which is what
/// keeps undo complete: there is no path that changes pixels without recording
/// how to put them back. Edits are serialised through [_serialize] because they
/// are asynchronous (rasterising goes through the engine) and two overlapping
/// commits would otherwise each build on the same stale bitmap, silently
/// dropping one of them.
class DocumentController extends ChangeNotifier {
  DocumentController({required int undoBudgetMb})
    : _history = History(budgetBytes: undoBudgetMb * 1024 * 1024);

  final History _history;

  PaintDocument? _document;

  Future<void> _queue = Future<void>.value();

  bool _disposed = false;

  bool get isReady => _document != null;

  /// The current document. Only valid once [newDocument] or [openImage] has
  /// completed; the app awaits one of those before building the UI.
  PaintDocument get document {
    final document = _document;
    if (document == null) {
      throw StateError('No document loaded yet');
    }
    return document;
  }

  History get history => _history;

  bool get canUndo => _history.canUndo;

  bool get canRedo => _history.canRedo;

  set undoBudgetMb(int value) => _history.budgetBytes = value * 1024 * 1024;

  /// Replaces the document with a blank [width] x [height] image.
  Future<void> newDocument({
    required int width,
    required int height,
    ui.Color background = const ui.Color(0xFFFFFFFF),
  }) {
    return _serialize(() async {
      final image = await ImageUtils.filled(width, height, background);
      _replaceDocument(PaintDocument.single(image));
    });
  }

  /// Replaces the document with [image], loaded from [filePath].
  ///
  /// Takes ownership of [image].
  Future<void> openImage(ui.Image image, {String? filePath}) {
    return _serialize(() async {
      _replaceDocument(PaintDocument.single(image, filePath: filePath));
    });
  }

  /// Records that the document was written to [filePath].
  void markSaved(String filePath) {
    final current = _document;
    if (current == null) return;
    _document = current.copyWith(filePath: filePath, isModified: false);
    notifyListeners();
  }

  /// Applies [draw] to the active layer, limited to [bounds].
  ///
  /// [bounds] is the tool's own estimate of what it touched; it is rounded out
  /// and clamped to the canvas, and only those pixels are kept for undo. A tool
  /// that under-reports its bounds will produce a clipped edit, so tools inflate
  /// by at least half their stroke width.
  Future<void> commitRegion({
    required ui.Rect bounds,
    required void Function(ui.Canvas canvas) draw,
    required String label,
  }) {
    return _serialize(() async {
      final current = document;
      final rect = ImageUtils.clampToImage(
        bounds,
        current.width,
        current.height,
      );
      if (rect == null) return;

      final layerIndex = current.activeLayerIndex;
      final source = current.activeImage;

      final before = await ImageUtils.extractRegion(source, rect);
      final updated = await ImageUtils.drawOver(source, (canvas) {
        // Clip so a tool that overdraws its declared bounds cannot leave marks
        // outside the region undo knows about.
        canvas.save();
        canvas.clipRect(rect);
        draw(canvas);
        canvas.restore();
      });
      final after = await ImageUtils.extractRegion(updated, rect);

      _history.push(
        RegionEdit(
          label: label,
          layerIndex: layerIndex,
          rect: rect,
          before: before,
          after: after,
        ),
      );
      _setDocument(current.withActiveImage(updated));
      source.dispose();
    });
  }

  /// Replaces the active layer's bitmap with [build]'s result.
  ///
  /// For operations with no small dirty region — resize, rotate, crop, colour
  /// adjustments. [build] receives the current bitmap and returns a new one.
  Future<void> commitCanvas({
    required Future<ui.Image> Function(ui.Image source) build,
    required String label,
  }) {
    return _serialize(() async {
      final current = document;
      final layerIndex = current.activeLayerIndex;
      final source = current.activeImage;

      final result = await build(source);
      if (identical(result, source)) return;

      _history.push(
        CanvasEdit(
          label: label,
          layerIndex: layerIndex,
          before: source.clone(),
          after: result.clone(),
        ),
      );
      _setDocument(current.withActiveImage(result));
      source.dispose();
    });
  }

  Future<void> undo() {
    return _serialize(() async {
      final entry = _history.takeUndo();
      if (entry == null) return;
      await _restore(entry, undoing: true);
    });
  }

  Future<void> redo() {
    return _serialize(() async {
      final entry = _history.takeRedo();
      if (entry == null) return;
      await _restore(entry, undoing: false);
    });
  }

  Future<void> _restore(HistoryEntry entry, {required bool undoing}) async {
    final current = document;
    switch (entry) {
      case RegionEdit(
        :final layerIndex,
        :final rect,
        :final before,
        :final after,
      ):
        final source = current.layers[layerIndex].image;
        final patch = undoing ? before : after;
        final updated = await ImageUtils.replaceRegion(source, rect, patch);
        _setDocument(current.withLayerImage(layerIndex, updated));
        source.dispose();
      case CanvasEdit(:final layerIndex, :final before, :final after):
        final source = current.layers[layerIndex].image;
        final restored = (undoing ? before : after).clone();
        _setDocument(current.withLayerImage(layerIndex, restored));
        source.dispose();
    }
  }

  void _replaceDocument(PaintDocument next) {
    _history.clear();
    final previous = _document;
    _document = next;
    if (previous != null) {
      for (final layer in previous.layers) {
        layer.image.dispose();
      }
    }
    notifyListeners();
  }

  void _setDocument(PaintDocument next) {
    _document = next;
    notifyListeners();
  }

  /// Runs [action] after every previously queued edit has finished.
  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      if (_disposed) {
        completer.completeError(StateError('Controller disposed'));
        return;
      }
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _history.clear();
    final current = _document;
    if (current != null) {
      for (final layer in current.layers) {
        layer.image.dispose();
      }
      _document = null;
    }
    super.dispose();
  }
}
