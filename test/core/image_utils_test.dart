import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:paint/core/image_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageUtils', () {
    test('filled produces the requested size and colour', () async {
      final image = await ImageUtils.filled(3, 2, const ui.Color(0xFF123456));
      final bytes = await ImageUtils.toStraightRgbaBytes(image);

      expect(image.width, 3);
      expect(image.height, 2);
      expect(bytes.sublist(0, 4), <int>[0x12, 0x34, 0x56, 0xFF]);
    });

    test(
      'filled with a transparent colour clears rather than blends',
      () async {
        final image = await ImageUtils.filled(1, 1, const ui.Color(0x00000000));
        final bytes = await ImageUtils.toStraightRgbaBytes(image);

        expect(bytes[3], 0);
      },
    );

    test('extractRegion returns just that rectangle', () async {
      final source = await ImageUtils.rasterize(
        width: 4,
        height: 1,
        draw: (canvas) {
          canvas.drawRect(
            const ui.Rect.fromLTWH(0, 0, 4, 1),
            ui.Paint()..color = const ui.Color(0xFFFFFFFF),
          );
          canvas.drawRect(
            const ui.Rect.fromLTWH(2, 0, 1, 1),
            ui.Paint()..color = const ui.Color(0xFF000000),
          );
        },
      );

      final region = await ImageUtils.extractRegion(
        source,
        const ui.Rect.fromLTWH(2, 0, 1, 1),
      );
      final bytes = await ImageUtils.toStraightRgbaBytes(region);

      expect(region.width, 1);
      expect(bytes.sublist(0, 4), <int>[0, 0, 0, 255]);
    });

    test('extractRegion leaves out-of-bounds area transparent', () async {
      final source = await ImageUtils.filled(2, 2, const ui.Color(0xFFFF0000));
      final region = await ImageUtils.extractRegion(
        source,
        const ui.Rect.fromLTWH(1, 1, 2, 2),
      );
      final bytes = await ImageUtils.toStraightRgbaBytes(region);

      expect(bytes.sublist(0, 4), <int>[
        255,
        0,
        0,
        255,
      ], reason: 'overlap kept');
      expect(bytes.sublist(4, 8), <int>[
        0,
        0,
        0,
        0,
      ], reason: 'outside is empty');
    });

    test('replaceRegion overwrites pixels including alpha', () async {
      final base = await ImageUtils.filled(2, 1, const ui.Color(0xFFFF0000));
      final patch = await ImageUtils.filled(1, 1, const ui.Color(0x00000000));

      final result = await ImageUtils.replaceRegion(
        base,
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        patch,
      );
      final bytes = await ImageUtils.toStraightRgbaBytes(result);

      expect(bytes[3], 0, reason: 'transparent patch really cleared');
      expect(bytes.sublist(4, 8), <int>[255, 0, 0, 255], reason: 'rest kept');
    });

    test('straight RGBA survives a round trip', () async {
      final original = await ImageUtils.filled(
        2,
        2,
        const ui.Color(0x8020C040),
      );
      final bytes = await ImageUtils.toStraightRgbaBytes(original);
      final rebuilt = await ImageUtils.fromStraightRgbaBytes(bytes, 2, 2);
      final rebuiltBytes = await ImageUtils.toStraightRgbaBytes(rebuilt);

      // Premultiplying and back is lossy at low alpha, so allow a little slack.
      for (var i = 0; i < 4; i++) {
        expect(rebuiltBytes[i], closeTo(bytes[i], 2));
      }
    });

    test('drawOver leaves the source untouched', () async {
      final source = await ImageUtils.filled(1, 1, const ui.Color(0xFFFF0000));
      final result = await ImageUtils.drawOver(source, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 1, 1),
          ui.Paint()..color = const ui.Color(0xFF0000FF),
        );
      });

      final sourceBytes = await ImageUtils.toStraightRgbaBytes(source);
      final resultBytes = await ImageUtils.toStraightRgbaBytes(result);

      expect(sourceBytes.sublist(0, 4), <int>[255, 0, 0, 255]);
      expect(resultBytes.sublist(0, 4), <int>[0, 0, 255, 255]);
    });

    group('clampToImage', () {
      test('rounds out to whole pixels', () {
        final rect = ImageUtils.clampToImage(
          const ui.Rect.fromLTWH(1.4, 2.6, 3.2, 1.1),
          100,
          100,
        );

        expect(rect, const ui.Rect.fromLTRB(1, 2, 5, 4));
      });

      test('clips to the image bounds', () {
        final rect = ImageUtils.clampToImage(
          const ui.Rect.fromLTRB(-10, -10, 500, 500),
          8,
          4,
        );

        expect(rect, const ui.Rect.fromLTRB(0, 0, 8, 4));
      });

      test('returns null when nothing overlaps', () {
        final rect = ImageUtils.clampToImage(
          const ui.Rect.fromLTWH(50, 50, 10, 10),
          8,
          8,
        );

        expect(rect, isNull);
      });
    });

    test('memoryBytes is four bytes per pixel', () async {
      final image = await ImageUtils.filled(10, 20, const ui.Color(0xFF000000));

      expect(ImageUtils.memoryBytes(image), 800);
    });
  });
}
