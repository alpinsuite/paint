import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Which resize handle of a floating selection is being dragged.
enum SelectionHandle {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  /// Position of the handle within the selection's bounding box, as a fraction.
  ui.Offset get anchor => switch (this) {
    SelectionHandle.topLeft => ui.Offset.zero,
    SelectionHandle.topCenter => const ui.Offset(0.5, 0),
    SelectionHandle.topRight => const ui.Offset(1, 0),
    SelectionHandle.centerLeft => const ui.Offset(0, 0.5),
    SelectionHandle.centerRight => const ui.Offset(1, 0.5),
    SelectionHandle.bottomLeft => const ui.Offset(0, 1),
    SelectionHandle.bottomCenter => const ui.Offset(0.5, 1),
    SelectionHandle.bottomRight => const ui.Offset(1, 1),
  };

  bool get movesLeft => anchor.dx == 0;

  bool get movesTop => anchor.dy == 0;

  bool get movesRight => anchor.dx == 1;

  bool get movesBottom => anchor.dy == 1;
}

/// A region of the image, optionally holding pixels that have been lifted out
/// of the layer and are being dragged around.
///
/// Selections start *anchored*: the shape is marked but the pixels are still
/// part of the layer. The first move or resize *lifts* them — the region is
/// erased from the layer and its pixels become [floating]. Anchoring stamps
/// them back down. That two-state model is what makes a selection feel like
/// Paint's rather than like a permanent crop.
@immutable
class Selection {
  const Selection({
    required this.path,
    required this.originalBounds,
    required this.currentBounds,
    this.floating,
  });

  Selection.rectangle(ui.Rect rect)
    : path = (ui.Path()..addRect(rect)),
      originalBounds = rect,
      currentBounds = rect,
      floating = null;

  /// Region shape, in the coordinates it was created in.
  final ui.Path path;

  /// Bounding box of [path] where the selection was made.
  final ui.Rect originalBounds;

  /// Where the selection sits now, after any move or resize.
  final ui.Rect currentBounds;

  /// Pixels lifted out of the layer, or null while the selection is still
  /// anchored.
  final ui.Image? floating;

  bool get isFloating => floating != null;

  bool get isEmpty => currentBounds.width < 1 || currentBounds.height < 1;

  /// True when the selection has been moved or resized from where it started.
  bool get isTransformed => currentBounds != originalBounds;

  /// Maps [originalBounds] onto [currentBounds]. Used to draw the outline of a
  /// free-form selection after it has been dragged.
  Float64List get transformMatrix {
    final scaleX = originalBounds.width == 0
        ? 1.0
        : currentBounds.width / originalBounds.width;
    final scaleY = originalBounds.height == 0
        ? 1.0
        : currentBounds.height / originalBounds.height;
    final dx = currentBounds.left - originalBounds.left * scaleX;
    final dy = currentBounds.top - originalBounds.top * scaleY;
    // Column-major 4x4.
    return Float64List.fromList(<double>[
      scaleX, 0, 0, 0, //
      0, scaleY, 0, 0, //
      0, 0, 1, 0, //
      dx, dy, 0, 1, //
    ]);
  }

  /// The outline as it currently appears on screen.
  ui.Path get transformedPath =>
      isTransformed ? path.transform(transformMatrix) : path;

  bool contains(ui.Offset point) => transformedPath.contains(point);

  Selection copyWith({
    ui.Path? path,
    ui.Rect? originalBounds,
    ui.Rect? currentBounds,
    ui.Image? floating,
  }) {
    return Selection(
      path: path ?? this.path,
      originalBounds: originalBounds ?? this.originalBounds,
      currentBounds: currentBounds ?? this.currentBounds,
      floating: floating ?? this.floating,
    );
  }

  Selection movedBy(ui.Offset delta) =>
      copyWith(currentBounds: currentBounds.shift(delta));

  /// Applies a drag of [delta] on [handle], keeping the opposite edge pinned.
  Selection resized(SelectionHandle handle, ui.Offset delta) {
    var left = currentBounds.left;
    var top = currentBounds.top;
    var right = currentBounds.right;
    var bottom = currentBounds.bottom;

    if (handle.movesLeft) left += delta.dx;
    if (handle.movesRight) right += delta.dx;
    if (handle.movesTop) top += delta.dy;
    if (handle.movesBottom) bottom += delta.dy;

    // Never let an edge cross the one opposite it; the selection would flip and
    // the floating pixels would be drawn inside out.
    const minimum = 2.0;
    if (right - left < minimum) {
      if (handle.movesLeft) {
        left = right - minimum;
      } else {
        right = left + minimum;
      }
    }
    if (bottom - top < minimum) {
      if (handle.movesTop) {
        top = bottom - minimum;
      } else {
        bottom = top + minimum;
      }
    }

    return copyWith(currentBounds: ui.Rect.fromLTRB(left, top, right, bottom));
  }

  /// The handle under [point], within [tolerance] image pixels, or null.
  SelectionHandle? handleAt(ui.Offset point, double tolerance) {
    for (final handle in SelectionHandle.values) {
      final position = ui.Offset(
        currentBounds.left + currentBounds.width * handle.anchor.dx,
        currentBounds.top + currentBounds.height * handle.anchor.dy,
      );
      if ((point - position).distance <= tolerance) return handle;
    }
    return null;
  }

  void dispose() => floating?.dispose();
}
