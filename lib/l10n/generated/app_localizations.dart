import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Application name shown in the window title and About dialog
  ///
  /// In en, this message translates to:
  /// **'Paint'**
  String get appTitle;

  /// Window title with the current document name
  ///
  /// In en, this message translates to:
  /// **'{document} - Paint'**
  String windowTitle(String document);

  /// No description provided for @untitledDocument.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledDocument;

  /// Prefix marking a document with unsaved changes
  ///
  /// In en, this message translates to:
  /// **'*{name}'**
  String modifiedMarker(String name);

  /// No description provided for @menuFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// No description provided for @menuImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get menuImage;

  /// No description provided for @menuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// No description provided for @actionNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get actionNew;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open...'**
  String get actionOpen;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As...'**
  String get actionSaveAs;

  /// No description provided for @actionRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'Recent Files'**
  String get actionRecentFiles;

  /// No description provided for @actionNoRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'No recent files'**
  String get actionNoRecentFiles;

  /// No description provided for @actionClearRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get actionClearRecentFiles;

  /// No description provided for @actionQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get actionQuit;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get actionRedo;

  /// No description provided for @actionCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get actionCut;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get actionPaste;

  /// No description provided for @actionPasteFrom.
  ///
  /// In en, this message translates to:
  /// **'Paste From...'**
  String get actionPasteFrom;

  /// No description provided for @actionCopyTo.
  ///
  /// In en, this message translates to:
  /// **'Copy To...'**
  String get actionCopyTo;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get actionSelectAll;

  /// No description provided for @actionDeselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get actionDeselect;

  /// No description provided for @actionInvertSelection.
  ///
  /// In en, this message translates to:
  /// **'Invert Selection'**
  String get actionInvertSelection;

  /// No description provided for @actionCropToSelection.
  ///
  /// In en, this message translates to:
  /// **'Crop to Selection'**
  String get actionCropToSelection;

  /// No description provided for @actionZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get actionZoomIn;

  /// No description provided for @actionZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get actionZoomOut;

  /// No description provided for @actionZoomNormal.
  ///
  /// In en, this message translates to:
  /// **'Actual Size'**
  String get actionZoomNormal;

  /// No description provided for @actionZoomFit.
  ///
  /// In en, this message translates to:
  /// **'Fit to Window'**
  String get actionZoomFit;

  /// No description provided for @actionToggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get actionToggleTheme;

  /// No description provided for @actionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences...'**
  String get actionPreferences;

  /// No description provided for @actionAbout.
  ///
  /// In en, this message translates to:
  /// **'About Paint'**
  String get actionAbout;

  /// No description provided for @imageFlipHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Flip Horizontal'**
  String get imageFlipHorizontal;

  /// No description provided for @imageFlipVertical.
  ///
  /// In en, this message translates to:
  /// **'Flip Vertical'**
  String get imageFlipVertical;

  /// No description provided for @imageRotate90Right.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° Right'**
  String get imageRotate90Right;

  /// No description provided for @imageRotate90Left.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° Left'**
  String get imageRotate90Left;

  /// No description provided for @imageRotate180.
  ///
  /// In en, this message translates to:
  /// **'Rotate 180°'**
  String get imageRotate180;

  /// No description provided for @imageResize.
  ///
  /// In en, this message translates to:
  /// **'Resize Image...'**
  String get imageResize;

  /// No description provided for @imageCanvasSize.
  ///
  /// In en, this message translates to:
  /// **'Canvas Size...'**
  String get imageCanvasSize;

  /// No description provided for @imageStretchSkew.
  ///
  /// In en, this message translates to:
  /// **'Stretch and Skew...'**
  String get imageStretchSkew;

  /// No description provided for @imageInvertColors.
  ///
  /// In en, this message translates to:
  /// **'Invert Colors'**
  String get imageInvertColors;

  /// No description provided for @imageClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Image'**
  String get imageClear;

  /// No description provided for @imageDrawOpaque.
  ///
  /// In en, this message translates to:
  /// **'Draw Opaque'**
  String get imageDrawOpaque;

  /// No description provided for @toolPencil.
  ///
  /// In en, this message translates to:
  /// **'Pencil'**
  String get toolPencil;

  /// No description provided for @toolBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get toolBrush;

  /// No description provided for @toolEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get toolEraser;

  /// No description provided for @toolFill.
  ///
  /// In en, this message translates to:
  /// **'Fill with Color'**
  String get toolFill;

  /// No description provided for @toolEyedropper.
  ///
  /// In en, this message translates to:
  /// **'Pick Color'**
  String get toolEyedropper;

  /// No description provided for @toolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get toolText;

  /// No description provided for @toolLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get toolLine;

  /// No description provided for @toolCurve.
  ///
  /// In en, this message translates to:
  /// **'Curve'**
  String get toolCurve;

  /// No description provided for @toolRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get toolRectangle;

  /// No description provided for @toolRoundedRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rounded Rectangle'**
  String get toolRoundedRectangle;

  /// No description provided for @toolEllipse.
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get toolEllipse;

  /// No description provided for @toolPolygon.
  ///
  /// In en, this message translates to:
  /// **'Polygon'**
  String get toolPolygon;

  /// No description provided for @toolSelectRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangular Selection'**
  String get toolSelectRectangle;

  /// No description provided for @toolSelectFreeform.
  ///
  /// In en, this message translates to:
  /// **'Free-Form Selection'**
  String get toolSelectFreeform;

  /// No description provided for @optionSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get optionSize;

  /// No description provided for @optionTip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get optionTip;

  /// No description provided for @optionTipRound.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get optionTipRound;

  /// No description provided for @optionTipSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get optionTipSquare;

  /// No description provided for @optionTipSlash.
  ///
  /// In en, this message translates to:
  /// **'Slash'**
  String get optionTipSlash;

  /// No description provided for @optionTipBackslash.
  ///
  /// In en, this message translates to:
  /// **'Backslash'**
  String get optionTipBackslash;

  /// No description provided for @optionFillStyle.
  ///
  /// In en, this message translates to:
  /// **'Fill style'**
  String get optionFillStyle;

  /// No description provided for @optionFillOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get optionFillOutline;

  /// No description provided for @optionFillSolid.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get optionFillSolid;

  /// No description provided for @optionFillBoth.
  ///
  /// In en, this message translates to:
  /// **'Outline and fill'**
  String get optionFillBoth;

  /// No description provided for @optionTolerance.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get optionTolerance;

  /// No description provided for @optionContiguous.
  ///
  /// In en, this message translates to:
  /// **'Contiguous'**
  String get optionContiguous;

  /// No description provided for @optionAntiAlias.
  ///
  /// In en, this message translates to:
  /// **'Smooth edges'**
  String get optionAntiAlias;

  /// No description provided for @optionCornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get optionCornerRadius;

  /// No description provided for @optionSelectionTransparent.
  ///
  /// In en, this message translates to:
  /// **'Transparent selection'**
  String get optionSelectionTransparent;

  /// No description provided for @optionEraseToSecondary.
  ///
  /// In en, this message translates to:
  /// **'Erase to secondary color'**
  String get optionEraseToSecondary;

  /// No description provided for @optionFontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get optionFontFamily;

  /// No description provided for @optionFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get optionFontSize;

  /// No description provided for @optionBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get optionBold;

  /// No description provided for @optionItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get optionItalic;

  /// No description provided for @optionUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get optionUnderline;

  /// No description provided for @optionAlignLeft.
  ///
  /// In en, this message translates to:
  /// **'Align left'**
  String get optionAlignLeft;

  /// No description provided for @optionAlignCenter.
  ///
  /// In en, this message translates to:
  /// **'Align center'**
  String get optionAlignCenter;

  /// No description provided for @optionAlignRight.
  ///
  /// In en, this message translates to:
  /// **'Align right'**
  String get optionAlignRight;

  /// No description provided for @optionOpaqueBackground.
  ///
  /// In en, this message translates to:
  /// **'Opaque background'**
  String get optionOpaqueBackground;

  /// No description provided for @colorPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary color'**
  String get colorPrimary;

  /// No description provided for @colorSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary color'**
  String get colorSecondary;

  /// No description provided for @colorSwapHint.
  ///
  /// In en, this message translates to:
  /// **'Swap primary and secondary colors'**
  String get colorSwapHint;

  /// No description provided for @colorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Colors...'**
  String get colorEdit;

  /// No description provided for @colorRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent colors'**
  String get colorRecent;

  /// No description provided for @colorDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Colors'**
  String get colorDialogTitle;

  /// No description provided for @colorHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get colorHue;

  /// No description provided for @colorSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get colorSaturation;

  /// No description provided for @colorValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get colorValue;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorAlpha.
  ///
  /// In en, this message translates to:
  /// **'Alpha'**
  String get colorAlpha;

  /// No description provided for @colorHex.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get colorHex;

  /// No description provided for @colorInvalidHex.
  ///
  /// In en, this message translates to:
  /// **'Enter a color like #3366FF'**
  String get colorInvalidHex;

  /// No description provided for @windowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// No description provided for @windowClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @newImageTitle.
  ///
  /// In en, this message translates to:
  /// **'New Image'**
  String get newImageTitle;

  /// No description provided for @resizeImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Resize Image'**
  String get resizeImageTitle;

  /// No description provided for @canvasSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Canvas Size'**
  String get canvasSizeTitle;

  /// No description provided for @stretchSkewTitle.
  ///
  /// In en, this message translates to:
  /// **'Stretch and Skew'**
  String get stretchSkewTitle;

  /// No description provided for @fieldWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get fieldWidth;

  /// No description provided for @fieldHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get fieldHeight;

  /// No description provided for @fieldUnitPixels.
  ///
  /// In en, this message translates to:
  /// **'Pixels'**
  String get fieldUnitPixels;

  /// No description provided for @fieldUnitPercent.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get fieldUnitPercent;

  /// No description provided for @fieldMaintainAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Maintain aspect ratio'**
  String get fieldMaintainAspectRatio;

  /// No description provided for @fieldAnchor.
  ///
  /// In en, this message translates to:
  /// **'Anchor'**
  String get fieldAnchor;

  /// No description provided for @fieldBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get fieldBackground;

  /// No description provided for @backgroundWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get backgroundWhite;

  /// No description provided for @backgroundTransparent.
  ///
  /// In en, this message translates to:
  /// **'Transparent'**
  String get backgroundTransparent;

  /// No description provided for @backgroundSecondaryColor.
  ///
  /// In en, this message translates to:
  /// **'Secondary color'**
  String get backgroundSecondaryColor;

  /// No description provided for @sectionStretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get sectionStretch;

  /// No description provided for @sectionSkew.
  ///
  /// In en, this message translates to:
  /// **'Skew'**
  String get sectionSkew;

  /// No description provided for @fieldHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get fieldHorizontal;

  /// No description provided for @fieldVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get fieldVertical;

  /// No description provided for @unitDegrees.
  ///
  /// In en, this message translates to:
  /// **'Degrees'**
  String get unitDegrees;

  /// No description provided for @buttonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get buttonOk;

  /// No description provided for @buttonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buttonCancel;

  /// No description provided for @buttonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get buttonSave;

  /// No description provided for @buttonDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get buttonDiscard;

  /// No description provided for @buttonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get buttonClose;

  /// No description provided for @buttonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get buttonReset;

  /// No description provided for @unsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Save changes?'**
  String get unsavedTitle;

  /// No description provided for @unsavedMessage.
  ///
  /// In en, this message translates to:
  /// **'“{document}” has unsaved changes. Your changes will be lost if you don\'t save them.'**
  String unsavedMessage(String document);

  /// Cursor position in image coordinates
  ///
  /// In en, this message translates to:
  /// **'{x}, {y} px'**
  String statusPosition(int x, int y);

  /// Image or selection size
  ///
  /// In en, this message translates to:
  /// **'{width} × {height} px'**
  String statusSize(int width, int height);

  /// No description provided for @statusSelection.
  ///
  /// In en, this message translates to:
  /// **'Selection: {width} × {height} px'**
  String statusSelection(int width, int height);

  /// No description provided for @statusZoom.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String statusZoom(int percent);

  /// No description provided for @actionCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopyToClipboard;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copiedToClipboard;

  /// No description provided for @copyImageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy the whole image to the clipboard, ready to paste elsewhere  (Ctrl+C)'**
  String get copyImageTooltip;

  /// No description provided for @copySelectionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy the selection to the clipboard, ready to paste elsewhere  (Ctrl+C)'**
  String get copySelectionTooltip;

  /// No description provided for @dropHint.
  ///
  /// In en, this message translates to:
  /// **'Drop an image to open it'**
  String get dropHint;

  /// No description provided for @dropHintPaste.
  ///
  /// In en, this message translates to:
  /// **'Hold Shift while dropping to paste into the current image'**
  String get dropHintPaste;

  /// No description provided for @fileTypeImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get fileTypeImages;

  /// No description provided for @fileTypeAllFiles.
  ///
  /// In en, this message translates to:
  /// **'All files'**
  String get fileTypeAllFiles;

  /// No description provided for @saveFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get saveFormatLabel;

  /// No description provided for @jpegQuality.
  ///
  /// In en, this message translates to:
  /// **'JPEG quality'**
  String get jpegQuality;

  /// No description provided for @errorOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open “{file}”.'**
  String errorOpenFailed(String file);

  /// No description provided for @errorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save “{file}”.'**
  String errorSaveFailed(String file);

  /// No description provided for @errorUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'“{extension}” images cannot be opened.'**
  String errorUnsupportedFormat(String extension);

  /// No description provided for @errorUnsupportedSaveFormat.
  ///
  /// In en, this message translates to:
  /// **'“{extension}” images cannot be saved. Choose another format.'**
  String errorUnsupportedSaveFormat(String extension);

  /// No description provided for @errorClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard does not contain an image.'**
  String get errorClipboardEmpty;

  /// No description provided for @errorClipboardWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not put the image on the clipboard.'**
  String get errorClipboardWriteFailed;

  /// No description provided for @errorImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The image is too large. The maximum size is {max} × {max} pixels.'**
  String errorImageTooLarge(int max);

  /// No description provided for @warningAlphaLoss.
  ///
  /// In en, this message translates to:
  /// **'This format does not support transparency. Transparent areas will be filled with white.'**
  String get warningAlphaLoss;

  /// No description provided for @warningLossy.
  ///
  /// In en, this message translates to:
  /// **'This format is lossy. Image quality will be reduced each time you save.'**
  String get warningLossy;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'A simple, easy-to-use image editor for Linux.'**
  String get aboutDescription;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// Control modifier key, shown in menu shortcut labels
  ///
  /// In en, this message translates to:
  /// **'Ctrl'**
  String get keyCtrl;

  /// Shift modifier key, shown in menu shortcut labels
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get keyShift;

  /// Alt modifier key, shown in menu shortcut labels
  ///
  /// In en, this message translates to:
  /// **'Alt'**
  String get keyAlt;

  /// Delete key, shown in menu shortcut labels
  ///
  /// In en, this message translates to:
  /// **'Del'**
  String get keyDelete;

  /// Abbreviation for pixels, shown after a numeric value
  ///
  /// In en, this message translates to:
  /// **'px'**
  String get unitPixels;

  /// Abbreviation for typographic points, shown after a font size
  ///
  /// In en, this message translates to:
  /// **'pt'**
  String get unitPoints;

  /// Licence line in the About dialog
  ///
  /// In en, this message translates to:
  /// **'Released under the GNU General Public License, version 3 or later.'**
  String get aboutLicense;

  /// Help menu command that checks the repository immediately
  ///
  /// In en, this message translates to:
  /// **'Check for Updates Now'**
  String get actionCheckUpdatesNow;

  /// Help menu toggle enabling a once-a-day update check
  ///
  /// In en, this message translates to:
  /// **'Check for Updates Automatically'**
  String get actionAutoCheckUpdates;

  /// Status bar notice that a newer version has been published
  ///
  /// In en, this message translates to:
  /// **'{version} available'**
  String updateAvailable(String version);

  /// Shown when an explicit update check finds nothing newer
  ///
  /// In en, this message translates to:
  /// **'Paint is up to date.'**
  String get updateUpToDate;

  /// Shown when an explicit update check could not complete
  ///
  /// In en, this message translates to:
  /// **'Could not reach the update repository.'**
  String get updateCheckFailed;

  /// Shown while an explicit update check is running
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get updateChecking;

  /// Tooltip on the status bar update notice
  ///
  /// In en, this message translates to:
  /// **'Copy the upgrade command'**
  String get updateUpgradeHint;

  /// Confirmation after copying the apt upgrade command
  ///
  /// In en, this message translates to:
  /// **'Command copied'**
  String get updateCommandCopied;

  /// Button that hides the update notice
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get updateDismiss;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
