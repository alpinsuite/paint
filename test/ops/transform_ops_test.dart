import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:paint/core/image_utils.dart';
import 'package:paint/ops/transform_ops.dart';

/// Reads one pixel as ARGB-ish channel list, straight (non-premultiplied).
Future<List<int>> pixelAt(ui.Image image, int x, int y) async {
  final bytes = await ImageUtils.toStraightRgbaBytes(image);
  final index = (y * image.width + x) * 4;
  return <int>[
    bytes[index],
    bytes[index + 1],
    bytes[index + 2],
    bytes[index + 3],
  ];
}

/// A 2x1 image: red on the left, blue on the right. Asymmetric on both axes
/// once combined with the vertical variant, so flips and rotations are
/// distinguishable.
Future<ui.Image> redBlueStrip() {
  return ImageUtils.rasterize(
    width: 2,
    height: 1,
    draw: (canvas) {
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        ui.Paint()..color = const ui.Color(0xFFFF0000),
      );
      canvas.drawRect(
        const ui.Rect.fromLTWH(1, 0, 1, 1),
        ui.Paint()..color = const ui.Color(0xFF0000FF),
      );
    },
  );
}

const List<int> red = <int>[255, 0, 0, 255];
const List<int> blue = <int>[0, 0, 255, 255];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransformOps', () {
    test('flipHorizontal swaps the columns', () async {
      final source = await redBlueStrip();
      final result = await TransformOps.flipHorizontal(source);

      expect(await pixelAt(result, 0, 0), blue);
      expect(await pixelAt(result, 1, 0), red);
      expect(result.width, 2);
      expect(result.height, 1);
    });

    test('flipVertical leaves a single-row image unchanged', () async {
      final source = await redBlueStrip();
      final result = await TransformOps.flipVertical(source);

      expect(await pixelAt(result, 0, 0), red);
      expect(await pixelAt(result, 1, 0), blue);
    });

    test('rotateQuarterTurns swaps the axes for odd turns', () async {
      final source = await redBlueStrip();
      final result = await TransformOps.rotateQuarterTurns(source, 1);

      expect(result.width, 1);
      expect(result.height, 2);
      // Clockwise: the left (red) pixel ends up on top.
      expect(await pixelAt(result, 0, 0), red);
      expect(await pixelAt(result, 0, 1), blue);
    });

    test('rotating four quarter turns returns the original', () async {
      final source = await redBlueStrip();
      var result = source;
      for (var i = 0; i < 4; i++) {
        result = await TransformOps.rotateQuarterTurns(result, 1);
      }

      expect(result.width, 2);
      expect(result.height, 1);
      expect(await pixelAt(result, 0, 0), red);
      expect(await pixelAt(result, 1, 0), blue);
    });

    test('rotateQuarterTurns by 0 copies rather than aliasing', () async {
      final source = await redBlueStrip();
      final result = await TransformOps.rotateQuarterTurns(source, 0);

      expect(identical(result, source), isFalse);
      expect(await pixelAt(result, 0, 0), red);
    });

    test('resize with nearest neighbour keeps exact colours', () async {
      final source = await redBlueStrip();
      final result = await TransformOps.resize(source, 4, 2, smooth: false);

      expect(result.width, 4);
      expect(result.height, 2);
      expect(await pixelAt(result, 0, 0), red);
      expect(await pixelAt(result, 3, 1), blue);
    });

    test('resizeCanvas keeps pixels and fills the new area', () async {
      final source = await redBlueStrip();
      final result = await TransformOps.resizeCanvas(
        source,
        4,
        2,
        background: const ui.Color(0xFF00FF00),
      );

      expect(result.width, 4);
      expect(result.height, 2);
      expect(await pixelAt(result, 0, 0), red, reason: 'original kept');
      expect(await pixelAt(result, 3, 1), <int>[
        0,
        255,
        0,
        255,
      ], reason: 'new area filled with the background');
    });

    test('resizeCanvas honours a centre anchor', () async {
      final source = await redBlueStrip();
      final result = await TransformOps.resizeCanvas(
        source,
        4,
        1,
        anchor: CanvasAnchor.center,
        background: const ui.Color(0x00000000),
      );

      expect(await pixelAt(result, 0, 0), <int>[0, 0, 0, 0]);
      expect(await pixelAt(result, 1, 0), red);
      expect(await pixelAt(result, 2, 0), blue);
    });

    test('invertColors inverts RGB and preserves alpha', () async {
      final source = await ImageUtils.filled(1, 1, const ui.Color(0x80FF0000));
      final result = await TransformOps.invertColors(source);
      final pixel = await pixelAt(result, 0, 0);

      expect(pixel[0], lessThan(8), reason: 'red inverted to ~0');
      expect(pixel[1], greaterThan(247));
      expect(pixel[2], greaterThan(247));
      expect(pixel[3], closeTo(128, 2), reason: 'alpha untouched');
    });

    test('grayscale collapses the channels', () async {
      final source = await ImageUtils.filled(1, 1, const ui.Color(0xFFFF0000));
      final result = await TransformOps.grayscale(source);
      final pixel = await pixelAt(result, 0, 0);

      expect(pixel[0], pixel[1]);
      expect(pixel[1], pixel[2]);
      expect(pixel[0], closeTo(76, 2), reason: 'Rec. 601 luma of pure red');
    });

    test('crop clamps a rectangle that runs off the image', () async {
      final source = await redBlueStrip();
      final result = await TransformOps.crop(
        source,
        const ui.Rect.fromLTWH(1, 0, 10, 10),
      );

      expect(result.width, 1);
      expect(result.height, 1);
      expect(await pixelAt(result, 0, 0), blue);
    });

    test('stretchAndSkew scales by percentage', () async {
      final source = await redBlueStrip();
      final result = await TransformOps.stretchAndSkew(
        source,
        stretchX: 200,
        stretchY: 300,
      );

      expect(result.width, 4);
      expect(result.height, 3);
    });

    test('stretchAndSkew grows the canvas to fit a shear', () async {
      final source = await ImageUtils.filled(
        10,
        10,
        const ui.Color(0xFFFF0000),
      );
      final result = await TransformOps.stretchAndSkew(source, skewX: 45);

      // tan(45°) = 1, so a 10px-tall image gains 10px of width.
      expect(result.width, 20);
      expect(result.height, 10);
    });
  });
}
