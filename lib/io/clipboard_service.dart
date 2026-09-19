import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import 'image_codecs.dart';

/// System clipboard access for images.
///
/// PNG is the interchange format: it is the one encoding every Linux desktop
/// toolkit agrees on, and it keeps the alpha channel that BMP — the other
/// common choice — would drop.
///
/// Reading goes through `pasteboard`. Writing does not: that package's Linux
/// plugin answers "not implemented" to `writeImage`, so the application
/// registers its own GTK channel in `linux/runner/clipboard_channel.cc`.
abstract final class ClipboardService {
  static const MethodChannel _channel = MethodChannel(
    'io.github.rbuache.paint/clipboard',
  );

  /// The clipboard image, or null when it holds something else.
  static Future<ui.Image?> readImage() async {
    final Uint8List? bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return await ImageCodecs.decodeBytes(bytes, filename: 'clipboard');
    } on ImageDecodeException {
      return null;
    }
  }

  /// Puts [image] on the clipboard.
  ///
  /// Returns false when the platform refused it, so the caller can say so
  /// rather than claiming a copy that did not happen.
  static Future<bool> writeImage(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return false;
    try {
      await _channel.invokeMethod<void>(
        'writeImage',
        data.buffer.asUint8List(),
      );
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
