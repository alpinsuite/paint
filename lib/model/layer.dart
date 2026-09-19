import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// One bitmap in a [PaintDocument].
///
/// Version 1 of the editor always has exactly one layer, matching classic
/// Paint. The type exists so that adding a layers panel later is an additive
/// change to the UI rather than a rewrite of the document, history and every
/// image operation.
@immutable
class Layer {
  const Layer({
    required this.image,
    required this.name,
    this.opacity = 1.0,
    this.visible = true,
  });

  /// The layer pixels. Owned by the layer: whoever replaces a layer is
  /// responsible for disposing the image it displaced.
  final ui.Image image;

  final String name;

  /// 0..1, multiplied into the layer when compositing.
  final double opacity;

  final bool visible;

  int get width => image.width;

  int get height => image.height;

  Layer copyWith({
    ui.Image? image,
    String? name,
    double? opacity,
    bool? visible,
  }) {
    return Layer(
      image: image ?? this.image,
      name: name ?? this.name,
      opacity: opacity ?? this.opacity,
      visible: visible ?? this.visible,
    );
  }
}
