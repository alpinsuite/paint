// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Paint';

  @override
  String windowTitle(String document) {
    return '$document - Paint';
  }

  @override
  String get untitledDocument => 'Untitled';

  @override
  String modifiedMarker(String name) {
    return '*$name';
  }

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuView => 'View';

  @override
  String get menuImage => 'Image';

  @override
  String get menuHelp => 'Help';

  @override
  String get actionNew => 'New';

  @override
  String get actionOpen => 'Open...';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSaveAs => 'Save As...';

  @override
  String get actionRecentFiles => 'Recent Files';

  @override
  String get actionNoRecentFiles => 'No recent files';

  @override
  String get actionClearRecentFiles => 'Clear list';

  @override
  String get actionQuit => 'Quit';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionRedo => 'Redo';

  @override
  String get actionCut => 'Cut';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionPaste => 'Paste';

  @override
  String get actionPasteFrom => 'Paste From...';

  @override
  String get actionCopyTo => 'Copy To...';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionSelectAll => 'Select All';

  @override
  String get actionDeselect => 'Deselect';

  @override
  String get actionInvertSelection => 'Invert Selection';

  @override
  String get actionCropToSelection => 'Crop to Selection';

  @override
  String get actionZoomIn => 'Zoom In';

  @override
  String get actionZoomOut => 'Zoom Out';

  @override
  String get actionZoomNormal => 'Actual Size';

  @override
  String get actionZoomFit => 'Fit to Window';

  @override
  String get actionToggleTheme => 'Appearance';

  @override
  String get actionPreferences => 'Preferences...';

  @override
  String get actionAbout => 'About Paint';

  @override
  String get imageFlipHorizontal => 'Flip Horizontal';

  @override
  String get imageFlipVertical => 'Flip Vertical';

  @override
  String get imageRotate90Right => 'Rotate 90° Right';

  @override
  String get imageRotate90Left => 'Rotate 90° Left';

  @override
  String get imageRotate180 => 'Rotate 180°';

  @override
  String get imageResize => 'Resize Image...';

  @override
  String get imageCanvasSize => 'Canvas Size...';

  @override
  String get imageStretchSkew => 'Stretch and Skew...';

  @override
  String get imageInvertColors => 'Invert Colors';

  @override
  String get imageClear => 'Clear Image';

  @override
  String get imageDrawOpaque => 'Draw Opaque';

  @override
  String get toolPencil => 'Pencil';

  @override
  String get toolBrush => 'Brush';

  @override
  String get toolEraser => 'Eraser';

  @override
  String get toolFill => 'Fill with Color';

  @override
  String get toolEyedropper => 'Pick Color';

  @override
  String get toolText => 'Text';

  @override
  String get toolLine => 'Line';

  @override
  String get toolCurve => 'Curve';

  @override
  String get toolRectangle => 'Rectangle';

  @override
  String get toolRoundedRectangle => 'Rounded Rectangle';

  @override
  String get toolEllipse => 'Ellipse';

  @override
  String get toolPolygon => 'Polygon';

  @override
  String get toolSelectRectangle => 'Rectangular Selection';

  @override
  String get toolSelectFreeform => 'Free-Form Selection';

  @override
  String get optionSize => 'Size';

  @override
  String get optionTip => 'Tip';

  @override
  String get optionTipRound => 'Round';

  @override
  String get optionTipSquare => 'Square';

  @override
  String get optionTipSlash => 'Slash';

  @override
  String get optionTipBackslash => 'Backslash';

  @override
  String get optionFillStyle => 'Fill style';

  @override
  String get optionFillOutline => 'Outline';

  @override
  String get optionFillSolid => 'Fill';

  @override
  String get optionFillBoth => 'Outline and fill';

  @override
  String get optionTolerance => 'Tolerance';

  @override
  String get optionContiguous => 'Contiguous';

  @override
  String get optionAntiAlias => 'Smooth edges';

  @override
  String get optionCornerRadius => 'Corner radius';

  @override
  String get optionSelectionTransparent => 'Transparent selection';

  @override
  String get optionEraseToSecondary => 'Erase to secondary color';

  @override
  String get optionFontFamily => 'Font';

  @override
  String get optionFontSize => 'Font size';

  @override
  String get optionBold => 'Bold';

  @override
  String get optionItalic => 'Italic';

  @override
  String get optionUnderline => 'Underline';

  @override
  String get optionAlignLeft => 'Align left';

  @override
  String get optionAlignCenter => 'Align center';

  @override
  String get optionAlignRight => 'Align right';

  @override
  String get optionOpaqueBackground => 'Opaque background';

  @override
  String get colorPrimary => 'Primary color';

  @override
  String get colorSecondary => 'Secondary color';

  @override
  String get colorSwapHint => 'Swap primary and secondary colors';

  @override
  String get colorEdit => 'Edit Colors...';

  @override
  String get colorRecent => 'Recent colors';

  @override
  String get colorDialogTitle => 'Edit Colors';

  @override
  String get colorHue => 'Hue';

  @override
  String get colorSaturation => 'Saturation';

  @override
  String get colorValue => 'Value';

  @override
  String get colorRed => 'Red';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorAlpha => 'Alpha';

  @override
  String get colorHex => 'Hex';

  @override
  String get colorInvalidHex => 'Enter a color like #3366FF';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get newImageTitle => 'New Image';

  @override
  String get resizeImageTitle => 'Resize Image';

  @override
  String get canvasSizeTitle => 'Canvas Size';

  @override
  String get stretchSkewTitle => 'Stretch and Skew';

  @override
  String get fieldWidth => 'Width';

  @override
  String get fieldHeight => 'Height';

  @override
  String get fieldUnitPixels => 'Pixels';

  @override
  String get fieldUnitPercent => 'Percentage';

  @override
  String get fieldMaintainAspectRatio => 'Maintain aspect ratio';

  @override
  String get fieldAnchor => 'Anchor';

  @override
  String get fieldBackground => 'Background';

  @override
  String get backgroundWhite => 'White';

  @override
  String get backgroundTransparent => 'Transparent';

  @override
  String get backgroundSecondaryColor => 'Secondary color';

  @override
  String get sectionStretch => 'Stretch';

  @override
  String get sectionSkew => 'Skew';

  @override
  String get fieldHorizontal => 'Horizontal';

  @override
  String get fieldVertical => 'Vertical';

  @override
  String get unitDegrees => 'Degrees';

  @override
  String get buttonOk => 'OK';

  @override
  String get buttonCancel => 'Cancel';

  @override
  String get buttonSave => 'Save';

  @override
  String get buttonDiscard => 'Discard';

  @override
  String get buttonClose => 'Close';

  @override
  String get buttonReset => 'Reset';

  @override
  String get unsavedTitle => 'Save changes?';

  @override
  String unsavedMessage(String document) {
    return '“$document” has unsaved changes. Your changes will be lost if you don\'t save them.';
  }

  @override
  String statusPosition(int x, int y) {
    return '$x, $y px';
  }

  @override
  String statusSize(int width, int height) {
    return '$width × $height px';
  }

  @override
  String statusSelection(int width, int height) {
    return 'Selection: $width × $height px';
  }

  @override
  String statusZoom(int percent) {
    return '$percent%';
  }

  @override
  String get actionCopyToClipboard => 'Copy';

  @override
  String get copiedToClipboard => 'Copied';

  @override
  String get copyImageTooltip =>
      'Copy the whole image to the clipboard, ready to paste elsewhere  (Ctrl+C)';

  @override
  String get copySelectionTooltip =>
      'Copy the selection to the clipboard, ready to paste elsewhere  (Ctrl+C)';

  @override
  String get dropHint => 'Drop an image to open it';

  @override
  String get dropHintPaste =>
      'Hold Shift while dropping to paste into the current image';

  @override
  String get fileTypeImages => 'Images';

  @override
  String get fileTypeAllFiles => 'All files';

  @override
  String get saveFormatLabel => 'Format';

  @override
  String get jpegQuality => 'JPEG quality';

  @override
  String errorOpenFailed(String file) {
    return 'Could not open “$file”.';
  }

  @override
  String errorSaveFailed(String file) {
    return 'Could not save “$file”.';
  }

  @override
  String errorUnsupportedFormat(String extension) {
    return '“$extension” images cannot be opened.';
  }

  @override
  String errorUnsupportedSaveFormat(String extension) {
    return '“$extension” images cannot be saved. Choose another format.';
  }

  @override
  String get errorClipboardEmpty => 'The clipboard does not contain an image.';

  @override
  String get errorClipboardWriteFailed =>
      'Could not put the image on the clipboard.';

  @override
  String errorImageTooLarge(int max) {
    return 'The image is too large. The maximum size is $max × $max pixels.';
  }

  @override
  String get warningAlphaLoss =>
      'This format does not support transparency. Transparent areas will be filled with white.';

  @override
  String get warningLossy =>
      'This format is lossy. Image quality will be reduced each time you save.';

  @override
  String get aboutDescription =>
      'A simple, easy-to-use image editor for Linux.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get keyCtrl => 'Ctrl';

  @override
  String get keyShift => 'Shift';

  @override
  String get keyAlt => 'Alt';

  @override
  String get keyDelete => 'Del';

  @override
  String get unitPixels => 'px';

  @override
  String get unitPoints => 'pt';

  @override
  String get aboutLicense =>
      'Released under the GNU General Public License, version 3 or later.';

  @override
  String get actionCheckUpdatesNow => 'Check for Updates Now';

  @override
  String get actionAutoCheckUpdates => 'Check for Updates Automatically';

  @override
  String updateAvailable(String version) {
    return '$version available';
  }

  @override
  String get updateUpToDate => 'Paint is up to date.';

  @override
  String get updateCheckFailed => 'Could not reach the update repository.';

  @override
  String get updateChecking => 'Checking for updates...';

  @override
  String get updateUpgradeHint => 'Copy the upgrade command';

  @override
  String get updateCommandCopied => 'Command copied';

  @override
  String get updateDismiss => 'Dismiss';
}
