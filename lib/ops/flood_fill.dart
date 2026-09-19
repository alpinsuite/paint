import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Input for a flood fill, shaped so it can cross an isolate boundary.
@immutable
class FloodFillRequest {
  const FloodFillRequest({
    required this.pixels,
    required this.width,
    required this.height,
    required this.startX,
    required this.startY,
    required this.fillR,
    required this.fillG,
    required this.fillB,
    required this.fillA,
    required this.tolerance,
    required this.contiguous,
  });

  /// Straight RGBA, row-major.
  final Uint8List pixels;
  final int width;
  final int height;
  final int startX;
  final int startY;
  final int fillR;
  final int fillG;
  final int fillB;
  final int fillA;

  /// Maximum per-channel distance, 0-255, that still counts as the same colour.
  final int tolerance;

  /// True fills only the region connected to the start pixel; false fills every
  /// matching pixel in the image.
  final bool contiguous;
}

@immutable
class FloodFillResult {
  const FloodFillResult({required this.pixels, required this.changed});

  final Uint8List pixels;

  /// False when the start pixel already had the fill colour, so the caller can
  /// skip pushing a no-op onto the undo stack.
  final bool changed;
}

/// Fills a connected (or global) region of same-coloured pixels.
///
/// Runs on a background isolate: a full-canvas fill on a large image is tens of
/// milliseconds of tight-loop work, which would drop frames on the UI thread.
Future<FloodFillResult> floodFill(FloodFillRequest request) {
  return Isolate.run(() => floodFillSync(request));
}

/// The flood fill itself. Exposed separately so tests can run it without an
/// isolate.
FloodFillResult floodFillSync(FloodFillRequest request) {
  final width = request.width;
  final height = request.height;
  final pixels = Uint8List.fromList(request.pixels);

  final startX = request.startX;
  final startY = request.startY;
  if (startX < 0 || startY < 0 || startX >= width || startY >= height) {
    return FloodFillResult(pixels: pixels, changed: false);
  }

  final startIndex = (startY * width + startX) * 4;
  final targetR = pixels[startIndex];
  final targetG = pixels[startIndex + 1];
  final targetB = pixels[startIndex + 2];
  final targetA = pixels[startIndex + 3];

  final fillR = request.fillR;
  final fillG = request.fillG;
  final fillB = request.fillB;
  final fillA = request.fillA;

  // Nothing to do when the target already is the fill colour. Without this a
  // contiguous fill would still terminate, but a global fill would rewrite the
  // whole image for no visible change.
  if (targetR == fillR &&
      targetG == fillG &&
      targetB == fillB &&
      targetA == fillA) {
    return FloodFillResult(pixels: pixels, changed: false);
  }

  final tolerance = request.tolerance;

  bool matches(int index) {
    final dr = (pixels[index] - targetR).abs();
    final dg = (pixels[index + 1] - targetG).abs();
    final db = (pixels[index + 2] - targetB).abs();
    final da = (pixels[index + 3] - targetA).abs();
    // Chebyshev distance: a single channel drifting past the tolerance is
    // enough to stop the fill, which matches how users read "tolerance".
    if (dr > tolerance) return false;
    if (dg > tolerance) return false;
    if (db > tolerance) return false;
    if (da > tolerance) return false;
    return true;
  }

  void paint(int index) {
    pixels[index] = fillR;
    pixels[index + 1] = fillG;
    pixels[index + 2] = fillB;
    pixels[index + 3] = fillA;
  }

  if (!request.contiguous) {
    var changed = false;
    for (var index = 0; index < pixels.length; index += 4) {
      if (matches(index)) {
        paint(index);
        changed = true;
      }
    }
    return FloodFillResult(pixels: pixels, changed: changed);
  }

  // Scanline flood fill. Each stack entry is a horizontal run to expand, which
  // keeps the stack shallow compared with pushing individual pixels.
  final filled = Uint8List(width * height);
  final stack = <int>[startX, startY];
  var changed = false;

  while (stack.isNotEmpty) {
    final y = stack.removeLast();
    final seedX = stack.removeLast();

    final rowStart = y * width;
    if (filled[rowStart + seedX] == 1) continue;
    if (!matches((rowStart + seedX) * 4)) continue;

    var left = seedX;
    while (left > 0 &&
        filled[rowStart + left - 1] == 0 &&
        matches((rowStart + left - 1) * 4)) {
      left--;
    }
    var right = seedX;
    while (right < width - 1 &&
        filled[rowStart + right + 1] == 0 &&
        matches((rowStart + right + 1) * 4)) {
      right++;
    }

    for (var x = left; x <= right; x++) {
      paint((rowStart + x) * 4);
      filled[rowStart + x] = 1;
      changed = true;
    }

    for (final neighbourY in <int>[y - 1, y + 1]) {
      if (neighbourY < 0 || neighbourY >= height) continue;
      final neighbourRow = neighbourY * width;
      var x = left;
      while (x <= right) {
        if (filled[neighbourRow + x] == 0 && matches((neighbourRow + x) * 4)) {
          stack
            ..add(x)
            ..add(neighbourY);
          // Skip the rest of this run; the seed we just pushed will claim it.
          while (x <= right &&
              filled[neighbourRow + x] == 0 &&
              matches((neighbourRow + x) * 4)) {
            x++;
          }
        }
        x++;
      }
    }
  }

  return FloodFillResult(pixels: pixels, changed: changed);
}
