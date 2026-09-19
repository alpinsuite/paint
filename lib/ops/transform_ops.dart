import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/image_utils.dart';

/// Where a resized canvas anchors the existing image.
enum CanvasAnchor {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  /// Fraction of the leftover space placed before the image, per axis.
  ui.Offset get alignment => switch (this) {
    CanvasAnchor.topLeft => ui.Offset.zero,
    CanvasAnchor.topCenter => const ui.Offset(0.5, 0),
    CanvasAnchor.topRight => const ui.Offset(1, 0),
    CanvasAnchor.centerLeft => const ui.Offset(0, 0.5),
    CanvasAnchor.center => const ui.Offset(0.5, 0.5),
    CanvasAnchor.centerRight => const ui.Offset(1, 0.5),
    CanvasAnchor.bottomLeft => const ui.Offset(0, 1),
    CanvasAnchor.bottomCenter => const ui.Offset(0.5, 1),
    CanvasAnchor.bottomRight => const ui.Offset(1, 1),
  };
}

/// Whole-image geometry and colour operations.
///
/// Each returns a brand-new image and never mutates its input, which is what
/// lets [DocumentController.commitCanvas] keep the original for undo.
abstract final class TransformOps {
  static Future<ui.Image> flipHorizontal(ui.Image source) {
    return ImageUtils.rasterize(
      width: source.width,
      height: source.height,
      draw: (canvas) {
        canvas.translate(source.width.toDouble(), 0);
        canvas.scale(-1, 1);
        canvas.drawImage(source, ui.Offset.zero, ui.Paint());
      },
    );
  }

  static Future<ui.Image> flipVertical(ui.Image source) {
    return ImageUtils.rasterize(
      width: source.width,
      height: source.height,
      draw: (canvas) {
        canvas.translate(0, source.height.toDouble());
        canvas.scale(1, -1);
        canvas.drawImage(source, ui.Offset.zero, ui.Paint());
      },
    );
  }

  /// Rotates by a multiple of 90°. [quarterTurns] is clockwise.
  static Future<ui.Image> rotateQuarterTurns(
    ui.Image source,
    int quarterTurns,
  ) {
    final turns = quarterTurns % 4;
    if (turns == 0) {
      return ImageUtils.drawOver(source, (_) {});
    }
    final swapsAxes = turns.isOdd;
    final width = swapsAxes ? source.height : source.width;
    final height = swapsAxes ? source.width : source.height;

    return ImageUtils.rasterize(
      width: width,
      height: height,
      draw: (canvas) {
        switch (turns) {
          case 1:
            canvas.translate(source.height.toDouble(), 0);
            canvas.rotate(math.pi / 2);
          case 2:
            canvas.translate(source.width.toDouble(), source.height.toDouble());
            canvas.rotate(math.pi);
          case 3:
            canvas.translate(0, source.width.toDouble());
            canvas.rotate(-math.pi / 2);
        }
        canvas.drawImage(source, ui.Offset.zero, ui.Paint());
      },
    );
  }

  /// Rotates by an arbitrary angle, growing the canvas to fit the result.
  static Future<ui.Image> rotate(
    ui.Image source,
    double degrees, {
    ui.Color background = const ui.Color(0x00000000),
  }) {
    final radians = degrees * math.pi / 180;
    final cos = math.cos(radians).abs();
    final sin = math.sin(radians).abs();
    final width = (source.width * cos + source.height * sin).ceil();
    final height = (source.width * sin + source.height * cos).ceil();

    return ImageUtils.rasterize(
      width: width,
      height: height,
      draw: (canvas) {
        canvas.drawColor(background, ui.BlendMode.src);
        canvas.translate(width / 2, height / 2);
        canvas.rotate(radians);
        canvas.translate(-source.width / 2, -source.height / 2);
        canvas.drawImage(
          source,
          ui.Offset.zero,
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
      },
    );
  }

  /// Scales the image to [width] x [height].
  ///
  /// [smooth] false gives nearest-neighbour, which is what pixel art and
  /// screenshots need; true gives a filtered resample for photographs.
  static Future<ui.Image> resize(
    ui.Image source,
    int width,
    int height, {
    bool smooth = true,
  }) {
    return ImageUtils.rasterize(
      width: width,
      height: height,
      draw: (canvas) {
        canvas.drawImageRect(
          source,
          ui.Rect.fromLTWH(
            0,
            0,
            source.width.toDouble(),
            source.height.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint()
            ..filterQuality = smooth
                ? ui.FilterQuality.high
                : ui.FilterQuality.none,
        );
      },
    );
  }

  /// Changes the canvas size without scaling the image, placing the existing
  /// pixels according to [anchor] and filling any new area with [background].
  static Future<ui.Image> resizeCanvas(
    ui.Image source,
    int width,
    int height, {
    CanvasAnchor anchor = CanvasAnchor.topLeft,
    ui.Color background = const ui.Color(0x00000000),
  }) {
    final alignment = anchor.alignment;
    final dx = (width - source.width) * alignment.dx;
    final dy = (height - source.height) * alignment.dy;

    return ImageUtils.rasterize(
      width: width,
      height: height,
      draw: (canvas) {
        canvas.drawColor(background, ui.BlendMode.src);
        canvas.drawImage(
          source,
          ui.Offset(dx.roundToDouble(), dy.roundToDouble()),
          ui.Paint(),
        );
      },
    );
  }

  /// Paint's Stretch and Skew, in one pass.
  ///
  /// [stretchX]/[stretchY] are percentages; [skewX]/[skewY] are degrees. The
  /// output canvas grows to contain the sheared result so nothing is clipped.
  static Future<ui.Image> stretchAndSkew(
    ui.Image source, {
    double stretchX = 100,
    double stretchY = 100,
    double skewX = 0,
    double skewY = 0,
    ui.Color background = const ui.Color(0x00000000),
  }) {
    final scaleX = stretchX / 100;
    final scaleY = stretchY / 100;
    final tanX = math.tan(skewX * math.pi / 180);
    final tanY = math.tan(skewY * math.pi / 180);

    final scaledWidth = source.width * scaleX;
    final scaledHeight = source.height * scaleY;
    final width = (scaledWidth + (scaledHeight * tanX).abs()).ceil();
    final height = (scaledHeight + (scaledWidth * tanY).abs()).ceil();

    // A negative skew shifts content left/up; translate it back so the result
    // stays inside the canvas.
    final offsetX = tanX < 0 ? (scaledHeight * tanX).abs() : 0.0;
    final offsetY = tanY < 0 ? (scaledWidth * tanY).abs() : 0.0;

    // Column-major 4x4 shear matrix. Built by hand rather than with Matrix4
    // so this file depends only on dart:ui.
    final matrix = Float64List.fromList(<double>[
      1, tanY, 0, 0, //
      tanX, 1, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1, //
    ]);

    return ImageUtils.rasterize(
      width: math.max(1, width),
      height: math.max(1, height),
      draw: (canvas) {
        canvas.drawColor(background, ui.BlendMode.src);
        canvas.translate(offsetX, offsetY);
        canvas.transform(matrix);
        canvas.scale(scaleX, scaleY);
        canvas.drawImage(
          source,
          ui.Offset.zero,
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
      },
    );
  }

  /// Inverts RGB while leaving alpha alone, so transparent areas stay
  /// transparent instead of turning into opaque white.
  static Future<ui.Image> invertColors(ui.Image source) {
    return _applyColorFilter(
      source,
      const ColorFilter.matrix(<double>[
        -1, 0, 0, 0, 255, //
        0, -1, 0, 0, 255, //
        0, 0, -1, 0, 255, //
        0, 0, 0, 1, 0, //
      ]),
    );
  }

  /// Rec. 601 luma weights — the same ones Paint and most editors use.
  static Future<ui.Image> grayscale(ui.Image source) {
    return _applyColorFilter(
      source,
      const ColorFilter.matrix(<double>[
        0.299, 0.587, 0.114, 0, 0, //
        0.299, 0.587, 0.114, 0, 0, //
        0.299, 0.587, 0.114, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
    );
  }

  static Future<ui.Image> _applyColorFilter(
    ui.Image source,
    ColorFilter filter,
  ) {
    return ImageUtils.rasterize(
      width: source.width,
      height: source.height,
      draw: (canvas) {
        canvas.drawImage(
          source,
          ui.Offset.zero,
          ui.Paint()..colorFilter = filter,
        );
      },
    );
  }

  /// Crops to [rect], which is clamped to the image first.
  static Future<ui.Image> crop(ui.Image source, ui.Rect rect) {
    final clamped =
        ImageUtils.clampToImage(rect, source.width, source.height) ??
        ui.Rect.fromLTWH(
          0,
          0,
          source.width.toDouble(),
          source.height.toDouble(),
        );
    return ImageUtils.extractRegion(source, clamped);
  }
}
