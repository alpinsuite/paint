import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Maps between screen and image coordinates, and owns zoom and pan.
///
/// The transform is a plain scale-then-translate — there is no rotation — so it
/// inverts exactly, which matters because every pointer position is round-
/// tripped through it and a drifting inverse would make drawing feel loose.
class ViewportController extends ChangeNotifier {
  /// Zoom steps the zoom-in/zoom-out commands walk through, as fractions.
  static const List<double> zoomSteps = <double>[
    0.125,
    0.25,
    0.5,
    0.75,
    1,
    2,
    3,
    4,
    6,
    8,
    12,
    16,
    24,
    32,
  ];

  static const double minZoom = 0.02;
  static const double maxZoom = 64;

  double _zoom = 1;
  ui.Offset _origin = ui.Offset.zero;
  ui.Size _viewportSize = ui.Size.zero;
  ui.Size _imageSize = ui.Size.zero;
  bool _hasBeenFitted = false;

  double get zoom => _zoom;

  /// Screen position of the image's top-left corner.
  ui.Offset get origin => _origin;

  ui.Size get viewportSize => _viewportSize;

  ui.Size get imageSize => _imageSize;

  /// Screen-space rectangle the image occupies.
  ui.Rect get imageScreenRect =>
      _origin & ui.Size(_imageSize.width * _zoom, _imageSize.height * _zoom);

  ui.Offset toImage(ui.Offset screenPoint) => (screenPoint - _origin) / _zoom;

  ui.Offset toScreen(ui.Offset imagePoint) => imagePoint * _zoom + _origin;

  /// Called by the canvas when its box or the document changes.
  void updateGeometry({required ui.Size viewport, required ui.Size image}) {
    final imageChanged = image != _imageSize;
    if (viewport == _viewportSize && !imageChanged) return;
    _viewportSize = viewport;
    _imageSize = image;
    // Fit the first image we are shown, and any image that replaces it, so a
    // freshly opened photo is visible in full instead of cropped to a corner.
    if (imageChanged || !_hasBeenFitted) {
      _hasBeenFitted = true;
      _fit(notify: false);
    } else {
      _clampOrigin();
    }
    notifyListeners();
  }

  /// Sets zoom to [value], keeping the image point under [focalPoint] fixed.
  void zoomTo(double value, {ui.Offset? focalPoint}) {
    final target = value.clamp(minZoom, maxZoom);
    if (target == _zoom) return;
    final focus = focalPoint ?? _viewportSize.center(ui.Offset.zero);
    final imagePoint = toImage(focus);
    _zoom = target;
    _origin = focus - imagePoint * target;
    _clampOrigin();
    notifyListeners();
  }

  void zoomIn({ui.Offset? focalPoint}) {
    final next = zoomSteps.firstWhere(
      (step) => step > _zoom + 1e-6,
      orElse: () => maxZoom,
    );
    zoomTo(next, focalPoint: focalPoint);
  }

  void zoomOut({ui.Offset? focalPoint}) {
    final next = zoomSteps.lastWhere(
      (step) => step < _zoom - 1e-6,
      orElse: () => minZoom,
    );
    zoomTo(next, focalPoint: focalPoint);
  }

  void zoomToActualSize() => zoomTo(1);

  /// Scales the image to fit the viewport, never enlarging past 100%.
  void fitToWindow() => _fit(notify: true);

  void _fit({required bool notify}) {
    if (_imageSize.isEmpty || _viewportSize.isEmpty) return;
    const padding = 24.0;
    final available = ui.Size(
      math.max(1, _viewportSize.width - padding),
      math.max(1, _viewportSize.height - padding),
    );
    final scale = math.min(
      available.width / _imageSize.width,
      available.height / _imageSize.height,
    );
    _zoom = scale.clamp(minZoom, 1.0);
    _centerOrigin();
    if (notify) notifyListeners();
  }

  /// Moves the view by a screen-space [delta].
  void panBy(ui.Offset delta) {
    if (delta == ui.Offset.zero) return;
    _origin += delta;
    _clampOrigin();
    notifyListeners();
  }

  void _centerOrigin() {
    _origin = ui.Offset(
      (_viewportSize.width - _imageSize.width * _zoom) / 2,
      (_viewportSize.height - _imageSize.height * _zoom) / 2,
    );
  }

  /// Keeps the image reachable: centred while it fits, and otherwise never
  /// dragged so far that no part of it is on screen.
  void _clampOrigin() {
    if (_imageSize.isEmpty || _viewportSize.isEmpty) return;
    final scaled = ui.Size(_imageSize.width * _zoom, _imageSize.height * _zoom);

    double axis(double origin, double viewport, double content) {
      if (content <= viewport) return (viewport - content) / 2;
      // Leave a margin so the edge of a zoomed image can be worked on.
      const margin = 48.0;
      final minOrigin = viewport - content - margin;
      const maxOrigin = margin;
      return origin.clamp(minOrigin, maxOrigin);
    }

    _origin = ui.Offset(
      axis(_origin.dx, _viewportSize.width, scaled.width),
      axis(_origin.dy, _viewportSize.height, scaled.height),
    );
  }
}
