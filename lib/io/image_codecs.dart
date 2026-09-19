import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../core/image_utils.dart';

/// One image format the editor knows about.
@immutable
class ImageFormatInfo {
  const ImageFormatInfo({
    required this.label,
    required this.extensions,
    required this.canEncode,
    this.supportsAlpha = true,
    this.lossy = false,
  });

  /// Shown in the file dialog's format list.
  final String label;

  /// Lower-case, without the leading dot. The first is the default on save.
  final List<String> extensions;

  /// False for formats that can only be read — the editor hides those from the
  /// Save As list rather than failing after the user has picked a name.
  final bool canEncode;

  final bool supportsAlpha;

  final bool lossy;

  String get primaryExtension => extensions.first;
}

/// Reads and writes the image formats the editor supports.
///
/// Decoding tries the engine's own decoder first because it is considerably
/// faster and produces a [ui.Image] directly; `package:image` is the fallback
/// that covers the formats the engine does not handle.
abstract final class ImageCodecs {
  static const List<ImageFormatInfo> formats = <ImageFormatInfo>[
    ImageFormatInfo(label: 'PNG', extensions: <String>['png'], canEncode: true),
    ImageFormatInfo(
      label: 'JPEG',
      extensions: <String>['jpg', 'jpeg'],
      canEncode: true,
      supportsAlpha: false,
      lossy: true,
    ),
    ImageFormatInfo(
      label: 'BMP',
      extensions: <String>['bmp'],
      canEncode: true,
      supportsAlpha: false,
    ),
    ImageFormatInfo(label: 'GIF', extensions: <String>['gif'], canEncode: true),
    ImageFormatInfo(
      label: 'TIFF',
      extensions: <String>['tif', 'tiff'],
      canEncode: true,
    ),
    ImageFormatInfo(label: 'TGA', extensions: <String>['tga'], canEncode: true),
    ImageFormatInfo(label: 'ICO', extensions: <String>['ico'], canEncode: true),
    // WebP and PSD decode only: package:image has no encoder for either.
    ImageFormatInfo(
      label: 'WebP',
      extensions: <String>['webp'],
      canEncode: false,
    ),
    ImageFormatInfo(
      label: 'Photoshop',
      extensions: <String>['psd'],
      canEncode: false,
    ),
    ImageFormatInfo(
      label: 'Netpbm',
      extensions: <String>['pnm', 'pbm', 'pgm', 'ppm'],
      canEncode: false,
    ),
  ];

  static List<ImageFormatInfo> get writableFormats =>
      formats.where((format) => format.canEncode).toList();

  /// Every readable extension, for the "Images" filter in the open dialog.
  static List<String> get readableExtensions =>
      formats.expand((format) => format.extensions).toList();

  static ImageFormatInfo? formatForExtension(String extension) {
    final normalised = extension.toLowerCase().replaceFirst('.', '');
    for (final format in formats) {
      if (format.extensions.contains(normalised)) return format;
    }
    return null;
  }

  static ImageFormatInfo? formatForPath(String path) =>
      formatForExtension(p.extension(path));

  /// Reads [path] into an image.
  ///
  /// Throws [ImageDecodeException] when the file is not an image the editor can
  /// read, so callers can show one message for every failure mode.
  static Future<ui.Image> decodeFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return decodeBytes(bytes, filename: p.basename(path));
  }

  static Future<ui.Image> decodeBytes(
    Uint8List bytes, {
    String filename = '',
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      // Fall through to package:image for TIFF, TGA, ICO, PSD, PNM and the
      // handful of PNG/BMP variants the engine rejects.
    }

    final decoded = await compute(_decodeWithImagePackage, bytes);
    if (decoded == null) {
      throw ImageDecodeException(filename);
    }
    return ImageUtils.fromStraightRgbaBytes(
      decoded.pixels,
      decoded.width,
      decoded.height,
    );
  }

  /// Encodes [image] in the format implied by [extension].
  ///
  /// Throws [UnsupportedImageFormatException] for a read-only format.
  static Future<Uint8List> encode(
    ui.Image image, {
    required String extension,
    int jpegQuality = 92,
    ui.Color flattenBackground = const ui.Color(0xFFFFFFFF),
  }) async {
    final format = formatForExtension(extension);
    if (format == null || !format.canEncode) {
      throw UnsupportedImageFormatException(extension);
    }

    // PNG round-trips through the engine, which is both faster and avoids a
    // needless straight/premultiplied conversion.
    if (format.primaryExtension == 'png') {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data != null) return data.buffer.asUint8List();
    }

    final source = format.supportsAlpha
        ? image
        : await _flatten(image, flattenBackground);
    try {
      final pixels = await ImageUtils.toStraightRgbaBytes(source);
      return compute(
        _encodeWithImagePackage,
        _EncodeRequest(
          pixels: pixels,
          width: source.width,
          height: source.height,
          extension: format.primaryExtension,
          jpegQuality: jpegQuality,
        ),
      );
    } finally {
      if (!identical(source, image)) source.dispose();
    }
  }

  /// Composites [image] onto an opaque [background], for formats with no alpha
  /// channel. Without this, transparent pixels come out black.
  static Future<ui.Image> _flatten(ui.Image image, ui.Color background) {
    return ImageUtils.rasterize(
      width: image.width,
      height: image.height,
      draw: (canvas) {
        canvas.drawColor(background, ui.BlendMode.src);
        canvas.drawImage(image, ui.Offset.zero, ui.Paint());
      },
    );
  }
}

/// Straight RGBA plus dimensions — the shape that crosses an isolate boundary.
class _DecodedImage {
  const _DecodedImage(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;
}

_DecodedImage? _decodeWithImagePackage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final rgba = decoded.convert(numChannels: 4, alpha: 255);
  return _DecodedImage(rgba.toUint8List(), rgba.width, rgba.height);
}

class _EncodeRequest {
  const _EncodeRequest({
    required this.pixels,
    required this.width,
    required this.height,
    required this.extension,
    required this.jpegQuality,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final String extension;
  final int jpegQuality;
}

Uint8List _encodeWithImagePackage(_EncodeRequest request) {
  final image = img.Image.fromBytes(
    width: request.width,
    height: request.height,
    bytes: request.pixels.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return switch (request.extension) {
    'jpg' => img.encodeJpg(image, quality: request.jpegQuality),
    'bmp' => img.encodeBmp(image),
    'gif' => img.encodeGif(image),
    'tif' => img.encodeTiff(image),
    'tga' => img.encodeTga(image),
    'ico' => img.encodeIco(image),
    _ => img.encodePng(image),
  };
}

/// The file could not be read as an image.
class ImageDecodeException implements Exception {
  const ImageDecodeException(this.filename);

  final String filename;

  @override
  String toString() => 'Could not decode image: $filename';
}

/// The requested format cannot be written.
class UnsupportedImageFormatException implements Exception {
  const UnsupportedImageFormatException(this.extension);

  final String extension;

  @override
  String toString() => 'Unsupported image format: $extension';
}
