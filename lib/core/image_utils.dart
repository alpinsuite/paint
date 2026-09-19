import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Low-level helpers for producing [ui.Image]s.
///
/// Everything the editor draws ends up going through [rasterize]: tools record
/// their drawing into a picture which is then baked into the document bitmap.
/// Recording is cheap, so the same drawing code can be replayed every frame for
/// the live preview and once more on commit — which is what guarantees that
/// what the user sees while dragging is exactly what lands in the image.
abstract final class ImageUtils {
  /// Largest image the editor will create. Beyond this the GPU texture limit
  /// and the undo budget both become a problem, so it is refused up front with
  /// a clear message rather than failing deep inside a draw call.
  static const int maxDimension = 20000;

  /// Records [draw] into a [width] x [height] image.
  static Future<ui.Image> rasterize({
    required int width,
    required int height,
    required void Function(ui.Canvas canvas) draw,
  }) async {
    assert(width > 0 && height > 0, 'rasterize needs a non-empty size');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    draw(canvas);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  /// A solid [color] image. Pass a transparent colour for an empty layer.
  static Future<ui.Image> filled(int width, int height, ui.Color color) {
    return rasterize(
      width: width,
      height: height,
      draw: (canvas) {
        // BlendMode.src rather than the default srcOver so a transparent
        // `color` produces genuinely empty pixels.
        canvas.drawColor(color, ui.BlendMode.src);
      },
    );
  }

  /// A copy of [source] with [draw] applied on top.
  static Future<ui.Image> drawOver(
    ui.Image source,
    void Function(ui.Canvas canvas) draw,
  ) {
    return rasterize(
      width: source.width,
      height: source.height,
      draw: (canvas) {
        canvas.drawImage(source, ui.Offset.zero, ui.Paint());
        draw(canvas);
      },
    );
  }

  /// The pixels of [source] inside [rect], as a standalone image.
  ///
  /// Parts of [rect] that fall outside [source] come back transparent, which is
  /// what lets an edit near the border store a rectangle that hangs off the
  /// canvas without special-casing the clamp.
  static Future<ui.Image> extractRegion(ui.Image source, ui.Rect rect) {
    final width = rect.width.round();
    final height = rect.height.round();
    return rasterize(
      width: width,
      height: height,
      draw: (canvas) {
        canvas.drawImage(
          source,
          -rect.topLeft,
          ui.Paint()..blendMode = ui.BlendMode.src,
        );
      },
    );
  }

  /// A copy of [base] with the pixels inside [rect] replaced by [patch].
  ///
  /// This is a replace, not a composite: it is how undo puts old pixels back,
  /// including their alpha.
  static Future<ui.Image> replaceRegion(
    ui.Image base,
    ui.Rect rect,
    ui.Image patch,
  ) {
    return rasterize(
      width: base.width,
      height: base.height,
      draw: (canvas) {
        canvas.drawImage(base, ui.Offset.zero, ui.Paint());
        canvas.save();
        canvas.clipRect(rect);
        canvas.drawImage(
          patch,
          rect.topLeft,
          ui.Paint()..blendMode = ui.BlendMode.src,
        );
        canvas.restore();
      },
    );
  }

  /// Straight (non-premultiplied) RGBA bytes, row-major, 4 bytes per pixel.
  ///
  /// Pixel operations work in straight alpha because that is the space users
  /// reason about: a 50%-transparent red is (255, 0, 0, 128) here, not the
  /// (128, 0, 0, 128) the engine stores internally. [fromStraightRgbaBytes]
  /// converts back.
  static Future<Uint8List> toStraightRgbaBytes(ui.Image image) async {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) {
      throw StateError('Could not read pixels from the image');
    }
    return data.buffer.asUint8List();
  }

  /// Builds an image from straight RGBA [bytes].
  static Future<ui.Image> fromStraightRgbaBytes(
    Uint8List bytes,
    int width,
    int height,
  ) {
    // decodeImageFromPixels interprets rgba8888 as premultiplied, so convert
    // in place on the copy we were handed.
    final premultiplied = Uint8List.fromList(bytes);
    for (var i = 0; i < premultiplied.length; i += 4) {
      final alpha = premultiplied[i + 3];
      if (alpha == 255) continue;
      if (alpha == 0) {
        premultiplied[i] = 0;
        premultiplied[i + 1] = 0;
        premultiplied[i + 2] = 0;
        continue;
      }
      premultiplied[i] = (premultiplied[i] * alpha) ~/ 255;
      premultiplied[i + 1] = (premultiplied[i + 1] * alpha) ~/ 255;
      premultiplied[i + 2] = (premultiplied[i + 2] * alpha) ~/ 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      premultiplied,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Rounds [rect] out to whole pixels and clamps it to a [width] x [height]
  /// image. Returns null when nothing is left — callers treat that as "this
  /// edit touched nothing".
  static ui.Rect? clampToImage(ui.Rect rect, int width, int height) {
    final clamped = ui.Rect.fromLTRB(
      rect.left.floorToDouble().clamp(0, width.toDouble()),
      rect.top.floorToDouble().clamp(0, height.toDouble()),
      rect.right.ceilToDouble().clamp(0, width.toDouble()),
      rect.bottom.ceilToDouble().clamp(0, height.toDouble()),
    );
    if (clamped.width < 1 || clamped.height < 1) return null;
    return clamped;
  }

  /// Bytes an image occupies as an RGBA texture. Used to police the undo
  /// budget, so an estimate is enough.
  static int memoryBytes(ui.Image image) => image.width * image.height * 4;
}
