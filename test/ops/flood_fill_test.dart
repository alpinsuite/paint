import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paint/ops/flood_fill.dart';

/// Builds a [width] x [height] straight-RGBA buffer filled with [color].
Uint8List _canvas(int width, int height, List<int> color) {
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = color[0];
    pixels[i + 1] = color[1];
    pixels[i + 2] = color[2];
    pixels[i + 3] = color[3];
  }
  return pixels;
}

void _set(Uint8List pixels, int width, int x, int y, List<int> color) {
  final index = (y * width + x) * 4;
  pixels[index] = color[0];
  pixels[index + 1] = color[1];
  pixels[index + 2] = color[2];
  pixels[index + 3] = color[3];
}

List<int> _get(Uint8List pixels, int width, int x, int y) {
  final index = (y * width + x) * 4;
  return <int>[
    pixels[index],
    pixels[index + 1],
    pixels[index + 2],
    pixels[index + 3],
  ];
}

const List<int> white = <int>[255, 255, 255, 255];
const List<int> black = <int>[0, 0, 0, 255];
const List<int> red = <int>[255, 0, 0, 255];

FloodFillRequest _request(
  Uint8List pixels,
  int width,
  int height, {
  required int x,
  required int y,
  List<int> fill = red,
  int tolerance = 0,
  bool contiguous = true,
}) {
  return FloodFillRequest(
    pixels: pixels,
    width: width,
    height: height,
    startX: x,
    startY: y,
    fillR: fill[0],
    fillG: fill[1],
    fillB: fill[2],
    fillA: fill[3],
    tolerance: tolerance,
    contiguous: contiguous,
  );
}

void main() {
  group('floodFillSync', () {
    test('fills the whole canvas when it is one uniform colour', () {
      final pixels = _canvas(8, 8, white);
      final result = floodFillSync(_request(pixels, 8, 8, x: 4, y: 4));

      expect(result.changed, isTrue);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          expect(_get(result.pixels, 8, x, y), red, reason: 'at $x,$y');
        }
      }
    });

    test('stops at a barrier and leaves the far side untouched', () {
      const width = 9;
      const height = 5;
      final pixels = _canvas(width, height, white);
      // A solid black column down the middle splits the canvas in two.
      for (var y = 0; y < height; y++) {
        _set(pixels, width, 4, y, black);
      }

      final result = floodFillSync(_request(pixels, width, height, x: 0, y: 0));

      expect(_get(result.pixels, width, 0, 0), red);
      expect(_get(result.pixels, width, 3, 4), red);
      expect(_get(result.pixels, width, 4, 2), black, reason: 'barrier intact');
      expect(_get(result.pixels, width, 5, 0), white, reason: 'far side kept');
      expect(_get(result.pixels, width, 8, 4), white);
    });

    test('reaches around a barrier that does not span the canvas', () {
      const width = 5;
      const height = 5;
      final pixels = _canvas(width, height, white);
      // Wall with a gap in the bottom row.
      for (var y = 0; y < height - 1; y++) {
        _set(pixels, width, 2, y, black);
      }

      final result = floodFillSync(_request(pixels, width, height, x: 0, y: 0));

      expect(
        _get(result.pixels, width, 4, 0),
        red,
        reason: 'flowed through gap',
      );
    });

    test('does nothing when the start pixel already has the fill colour', () {
      final pixels = _canvas(4, 4, red);
      final result = floodFillSync(_request(pixels, 4, 4, x: 1, y: 1));

      expect(result.changed, isFalse);
    });

    test('tolerance lets near-matching pixels through', () {
      const width = 3;
      final pixels = _canvas(width, 1, white);
      _set(pixels, width, 1, 0, <int>[250, 250, 250, 255]);

      final strict = floodFillSync(
        _request(pixels, width, 1, x: 0, y: 0, tolerance: 0),
      );
      expect(
        _get(strict.pixels, width, 2, 0),
        white,
        reason: 'blocked by the 5-level difference',
      );

      final loose = floodFillSync(
        _request(pixels, width, 1, x: 0, y: 0, tolerance: 8),
      );
      expect(
        _get(loose.pixels, width, 2, 0),
        red,
        reason: 'tolerance absorbed it',
      );
    });

    test('non-contiguous mode recolours matching pixels anywhere', () {
      const width = 5;
      const height = 1;
      final pixels = _canvas(width, height, white);
      _set(pixels, width, 2, 0, black);

      final result = floodFillSync(
        _request(pixels, width, height, x: 0, y: 0, contiguous: false),
      );

      expect(_get(result.pixels, width, 0, 0), red);
      expect(_get(result.pixels, width, 2, 0), black, reason: 'not a match');
      expect(
        _get(result.pixels, width, 4, 0),
        red,
        reason: 'filled despite being cut off',
      );
    });

    test('a start point outside the canvas is a no-op', () {
      final pixels = _canvas(4, 4, white);
      final result = floodFillSync(_request(pixels, 4, 4, x: 9, y: 0));

      expect(result.changed, isFalse);
      expect(_get(result.pixels, 4, 0, 0), white);
    });

    test('does not modify the caller\'s buffer', () {
      final pixels = _canvas(4, 4, white);
      floodFillSync(_request(pixels, 4, 4, x: 0, y: 0));

      expect(_get(pixels, 4, 0, 0), white);
    });
  });
}
