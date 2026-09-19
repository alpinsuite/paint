import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:paint/core/image_utils.dart';
import 'package:paint/io/image_codecs.dart';

/// A small image with three distinct opaque colours, so a round trip that
/// silently swapped channels would be caught.
Future<ui.Image> sampleImage() {
  return ImageUtils.rasterize(
    width: 3,
    height: 1,
    draw: (canvas) {
      const colors = <ui.Color>[
        ui.Color(0xFFFF0000),
        ui.Color(0xFF00FF00),
        ui.Color(0xFF0000FF),
      ];
      for (var x = 0; x < colors.length; x++) {
        canvas.drawRect(
          ui.Rect.fromLTWH(x.toDouble(), 0, 1, 1),
          ui.Paint()..color = colors[x],
        );
      }
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('format registry', () {
    test('maps extensions to formats, case- and dot-insensitively', () {
      expect(ImageCodecs.formatForExtension('png')?.label, 'PNG');
      expect(ImageCodecs.formatForExtension('.PNG')?.label, 'PNG');
      expect(ImageCodecs.formatForExtension('jpeg')?.label, 'JPEG');
      expect(ImageCodecs.formatForPath('/tmp/holiday.TIFF')?.label, 'TIFF');
    });

    test('returns null for a format the editor does not handle', () {
      expect(ImageCodecs.formatForExtension('xcf'), isNull);
      expect(ImageCodecs.formatForPath('/tmp/notes.txt'), isNull);
    });

    test('read-only formats are excluded from the save list', () {
      final writable = ImageCodecs.writableFormats.map((f) => f.label);

      expect(writable, contains('PNG'));
      expect(
        writable,
        isNot(contains('WebP')),
        reason: 'package:image cannot encode WebP',
      );
      expect(writable, isNot(contains('Photoshop')));
    });

    test('WebP and PSD are still offered for opening', () {
      expect(ImageCodecs.readableExtensions, contains('webp'));
      expect(ImageCodecs.readableExtensions, contains('psd'));
    });

    test('JPEG is flagged lossy and alpha-free', () {
      final jpeg = ImageCodecs.formatForExtension('jpg')!;

      expect(jpeg.lossy, isTrue);
      expect(jpeg.supportsAlpha, isFalse);
    });
  });

  group('encode and decode', () {
    test('PNG round-trips pixel for pixel', () async {
      final source = await sampleImage();
      final bytes = await ImageCodecs.encode(source, extension: 'png');
      final decoded = await ImageCodecs.decodeBytes(bytes);
      final pixels = await ImageUtils.toStraightRgbaBytes(decoded);

      expect(decoded.width, 3);
      expect(decoded.height, 1);
      expect(pixels.sublist(0, 4), <int>[255, 0, 0, 255]);
      expect(pixels.sublist(4, 8), <int>[0, 255, 0, 255]);
      expect(pixels.sublist(8, 12), <int>[0, 0, 255, 255]);
    });

    test('PNG keeps transparency', () async {
      final source = await ImageUtils.filled(2, 2, const ui.Color(0x00000000));
      final bytes = await ImageCodecs.encode(source, extension: 'png');
      final decoded = await ImageCodecs.decodeBytes(bytes);
      final pixels = await ImageUtils.toStraightRgbaBytes(decoded);

      expect(pixels[3], 0);
    });

    test('BMP round-trips', () async {
      final source = await sampleImage();
      final bytes = await ImageCodecs.encode(source, extension: 'bmp');
      final decoded = await ImageCodecs.decodeBytes(bytes);

      expect(decoded.width, 3);
      expect(decoded.height, 1);
    });

    test('TIFF round-trips', () async {
      final source = await sampleImage();
      final bytes = await ImageCodecs.encode(source, extension: 'tif');
      final decoded = await ImageCodecs.decodeBytes(bytes);

      expect(decoded.width, 3);
      expect(decoded.height, 1);
    });

    test('TGA round-trips', () async {
      final source = await sampleImage();
      final bytes = await ImageCodecs.encode(source, extension: 'tga');
      final decoded = await ImageCodecs.decodeBytes(bytes);

      expect(decoded.width, 3);
      expect(decoded.height, 1);
    });

    test('JPEG decodes back at the right size', () async {
      final source = await sampleImage();
      final bytes = await ImageCodecs.encode(
        source,
        extension: 'jpg',
        jpegQuality: 100,
      );
      final decoded = await ImageCodecs.decodeBytes(bytes);

      expect(decoded.width, 3);
      expect(decoded.height, 1);
    });

    test('JPEG flattens transparency onto the background', () async {
      final source = await ImageUtils.filled(2, 2, const ui.Color(0x00000000));
      final bytes = await ImageCodecs.encode(
        source,
        extension: 'jpg',
        jpegQuality: 100,
        flattenBackground: const ui.Color(0xFFFFFFFF),
      );
      final decoded = await ImageCodecs.decodeBytes(bytes);
      final pixels = await ImageUtils.toStraightRgbaBytes(decoded);

      expect(pixels[3], 255, reason: 'JPEG is always opaque');
      expect(pixels[0], greaterThan(240), reason: 'flattened onto white');
    });

    test('encoding a read-only format is refused', () async {
      final source = await sampleImage();

      expect(
        () => ImageCodecs.encode(source, extension: 'webp'),
        throwsA(isA<UnsupportedImageFormatException>()),
      );
    });

    test('decoding rubbish throws rather than returning a blank image', () {
      expect(
        () => ImageCodecs.decodeBytes(
          Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]),
          filename: 'broken.png',
        ),
        throwsA(isA<ImageDecodeException>()),
      );
    });
  });
}
