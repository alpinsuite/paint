import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../controller/document_controller.dart';
import '../core/settings/settings_controller.dart';
import 'image_codecs.dart';

/// What a save or open attempt produced, so the UI can report it without
/// this layer needing a [BuildContext] or the localisations.
sealed class FileResult {
  const FileResult();
}

/// The user dismissed the file dialog.
class FileCancelled extends FileResult {
  const FileCancelled();
}

class FileSucceeded extends FileResult {
  const FileSucceeded(this.path);

  final String path;
}

/// Something went wrong; [kind] tells the UI which message to show.
class FileFailed extends FileResult {
  const FileFailed(this.kind, this.path, {this.detail});

  final FileFailureKind kind;
  final String path;
  final Object? detail;
}

enum FileFailureKind { decode, encode, unsupportedFormat, io, tooLarge }

/// Opening and saving images.
///
/// Deliberately free of Flutter widgets: it returns a [FileResult] and lets the
/// caller decide how to present it, which keeps the file dialogs testable and
/// the error strings in one place in the UI layer.
class FileService {
  FileService({required this.documents, required this.settings});

  final DocumentController documents;
  final SettingsController settings;

  static XTypeGroup get _readableGroup =>
      XTypeGroup(label: 'Images', extensions: ImageCodecs.readableExtensions);

  static List<XTypeGroup> get _writableGroups => <XTypeGroup>[
    for (final format in ImageCodecs.writableFormats)
      XTypeGroup(label: format.label, extensions: format.extensions),
  ];

  /// Shows the open dialog and loads the chosen file.
  Future<FileResult> open() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        _readableGroup,
        const XTypeGroup(label: 'All files'),
      ],
    );
    if (file == null) return const FileCancelled();
    return openPath(file.path);
  }

  /// Loads [path] into the editor.
  Future<FileResult> openPath(String path) async {
    try {
      final image = await ImageCodecs.decodeFile(path);
      if (image.width > ImageUtilsLimits.maxDimension ||
          image.height > ImageUtilsLimits.maxDimension) {
        image.dispose();
        return FileFailed(FileFailureKind.tooLarge, path);
      }
      await documents.openImage(image, filePath: path);
      await settings.addRecentFile(path);
      return FileSucceeded(path);
    } on ImageDecodeException catch (error) {
      return FileFailed(FileFailureKind.decode, path, detail: error);
    } on FileSystemException catch (error) {
      return FileFailed(FileFailureKind.io, path, detail: error);
    }
  }

  /// Saves to the document's existing path, falling back to Save As when it has
  /// never been saved or its format cannot be written.
  Future<FileResult> save() async {
    final path = documents.document.filePath;
    if (path == null) return saveAs();
    final format = ImageCodecs.formatForPath(path);
    if (format == null || !format.canEncode) return saveAs();
    return _writeTo(path);
  }

  /// Shows the save dialog and writes the document there.
  Future<FileResult> saveAs() async {
    final current = documents.document.filePath;
    final location = await getSaveLocation(
      acceptedTypeGroups: _writableGroups,
      suggestedName: current == null
          ? 'untitled.png'
          : '${p.basenameWithoutExtension(current)}.png',
    );
    if (location == null) return const FileCancelled();

    // GTK's save dialog does not always append the extension of the selected
    // filter, so default to PNG rather than writing a file with no suffix.
    var path = location.path;
    if (p.extension(path).isEmpty) path = '$path.png';
    return _writeTo(path);
  }

  Future<FileResult> _writeTo(String path) async {
    final format = ImageCodecs.formatForPath(path);
    if (format == null || !format.canEncode) {
      return FileFailed(FileFailureKind.unsupportedFormat, path);
    }
    try {
      final bytes = await ImageCodecs.encode(
        documents.document.activeImage,
        extension: format.primaryExtension,
        jpegQuality: settings.jpegQuality,
      );
      await File(path).writeAsBytes(bytes, flush: true);
      documents.markSaved(path);
      await settings.addRecentFile(path);
      return FileSucceeded(path);
    } on UnsupportedImageFormatException {
      return FileFailed(FileFailureKind.unsupportedFormat, path);
    } on FileSystemException catch (error) {
      return FileFailed(FileFailureKind.io, path, detail: error);
    }
  }

  /// Writes the current image to [path] without changing the document's own
  /// path — Paint's "Copy To".
  Future<FileResult> copyTo() async {
    final location = await getSaveLocation(
      acceptedTypeGroups: _writableGroups,
      suggestedName: 'selection.png',
    );
    if (location == null) return const FileCancelled();
    var path = location.path;
    if (p.extension(path).isEmpty) path = '$path.png';

    final format = ImageCodecs.formatForPath(path);
    if (format == null || !format.canEncode) {
      return FileFailed(FileFailureKind.unsupportedFormat, path);
    }
    try {
      final bytes = await ImageCodecs.encode(
        documents.document.activeImage,
        extension: format.primaryExtension,
        jpegQuality: settings.jpegQuality,
      );
      await File(path).writeAsBytes(bytes, flush: true);
      return FileSucceeded(path);
    } on FileSystemException catch (error) {
      return FileFailed(FileFailureKind.io, path, detail: error);
    }
  }

  /// Reads an image file for pasting into the current document.
  Future<ui.Image?> readImageForPaste() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_readableGroup],
    );
    if (file == null) return null;
    try {
      return await ImageCodecs.decodeFile(file.path);
    } on ImageDecodeException {
      return null;
    }
  }
}

/// Re-exported so [FileService] does not have to import the whole image utility
/// surface just for one constant.
abstract final class ImageUtilsLimits {
  static const int maxDimension = 20000;
}
