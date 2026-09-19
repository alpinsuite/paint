import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'layer.dart';

/// The image being edited, plus where it came from.
///
/// Immutable: every edit produces a new document. That is what makes undo a
/// matter of swapping which document is current rather than trying to reverse
/// mutations in place.
@immutable
class PaintDocument {
  const PaintDocument({
    required this.layers,
    required this.activeLayerIndex,
    this.filePath,
    this.isModified = false,
  }) : assert(layers.length > 0, 'a document needs at least one layer');

  PaintDocument.single(
    ui.Image image, {
    this.filePath,
    this.isModified = false,
    String layerName = 'Background',
  }) : layers = <Layer>[Layer(image: image, name: layerName)],
       activeLayerIndex = 0;

  final List<Layer> layers;

  final int activeLayerIndex;

  /// Absolute path this document was last read from or written to. Null for a
  /// document that has never been saved.
  final String? filePath;

  /// True when there are edits that have not been written to [filePath].
  final bool isModified;

  Layer get activeLayer => layers[activeLayerIndex];

  ui.Image get activeImage => activeLayer.image;

  int get width => layers.first.width;

  int get height => layers.first.height;

  ui.Size get size => ui.Size(width.toDouble(), height.toDouble());

  ui.Rect get bounds => ui.Offset.zero & size;

  /// File name for the window title, or null when unsaved.
  String? get fileName {
    final path = filePath;
    return path == null ? null : p.basename(path);
  }

  PaintDocument copyWith({
    List<Layer>? layers,
    int? activeLayerIndex,
    String? filePath,
    bool? isModified,
    bool clearFilePath = false,
  }) {
    return PaintDocument(
      layers: layers ?? this.layers,
      activeLayerIndex: activeLayerIndex ?? this.activeLayerIndex,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      isModified: isModified ?? this.isModified,
    );
  }

  /// Replaces the pixels of the active layer.
  PaintDocument withActiveImage(ui.Image image, {bool modified = true}) {
    final updated = <Layer>[...layers];
    updated[activeLayerIndex] = activeLayer.copyWith(image: image);
    return copyWith(layers: updated, isModified: modified);
  }

  /// Replaces the pixels of the layer at [index].
  PaintDocument withLayerImage(
    int index,
    ui.Image image, {
    bool modified = true,
  }) {
    final updated = <Layer>[...layers];
    updated[index] = updated[index].copyWith(image: image);
    return copyWith(layers: updated, isModified: modified);
  }
}
