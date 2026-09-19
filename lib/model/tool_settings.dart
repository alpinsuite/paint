import 'package:flutter/material.dart';

/// Every tool the editor offers.
enum ToolId {
  pencil,
  brush,
  eraser,
  fill,
  eyedropper,
  text,
  line,
  curve,
  rectangle,
  roundedRectangle,
  ellipse,
  polygon,
  selectRectangle,
  selectFreeform,
}

/// Controls a tool wants shown in the options bar.
enum ToolOption {
  size,
  tip,
  fillStyle,
  tolerance,
  contiguous,
  antiAlias,
  cornerRadius,
  eraseToSecondary,
  selectionTransparent,
  text,
}

/// Brush tip shapes, matching classic Paint's brush picker.
enum BrushTip { round, square, slashForward, slashBackward }

/// Whether a shape draws its outline, its interior, or both.
enum FillStyle { outline, filled, outlineAndFill }

/// Modifier keys and mouse button for the current gesture.
@immutable
class ToolModifiers {
  const ToolModifiers({
    this.shift = false,
    this.control = false,
    this.alt = false,
    this.secondaryButton = false,
  });

  /// Constrains lines to 45° steps and shapes to squares/circles.
  final bool shift;

  /// Draws shapes centred on the press point.
  final bool control;

  final bool alt;

  /// True when the gesture was started with the right mouse button, which
  /// swaps the primary and secondary colours.
  final bool secondaryButton;
}

/// Tool state shared across gestures: colours, sizes and per-tool options.
class ToolSettings extends ChangeNotifier {
  ToolId _activeTool = ToolId.pencil;
  Color _primaryColor = const Color(0xFF000000);
  Color _secondaryColor = const Color(0xFFFFFFFF);
  double _strokeWidth = 1;
  BrushTip _brushTip = BrushTip.round;
  FillStyle _fillStyle = FillStyle.outline;
  int _tolerance = 16;
  bool _contiguous = true;
  bool _antiAlias = true;
  double _cornerRadius = 12;
  bool _eraseToSecondary = false;
  bool _selectionTransparent = false;
  String _fontFamily = 'Sans';
  double _fontSize = 24;
  bool _bold = false;
  bool _italic = false;
  bool _underline = false;
  TextAlign _textAlign = TextAlign.left;
  bool _textOpaqueBackground = false;

  ToolId get activeTool => _activeTool;

  set activeTool(ToolId value) {
    if (_activeTool == value) return;
    _activeTool = value;
    notifyListeners();
  }

  Color get primaryColor => _primaryColor;

  set primaryColor(Color value) {
    if (_primaryColor == value) return;
    _primaryColor = value;
    notifyListeners();
  }

  Color get secondaryColor => _secondaryColor;

  set secondaryColor(Color value) {
    if (_secondaryColor == value) return;
    _secondaryColor = value;
    notifyListeners();
  }

  void swapColors() {
    final previous = _primaryColor;
    _primaryColor = _secondaryColor;
    _secondaryColor = previous;
    notifyListeners();
  }

  /// Stroke width in image pixels.
  double get strokeWidth => _strokeWidth;

  set strokeWidth(double value) {
    final clamped = value.clamp(1.0, 200.0);
    if (_strokeWidth == clamped) return;
    _strokeWidth = clamped;
    notifyListeners();
  }

  BrushTip get brushTip => _brushTip;

  set brushTip(BrushTip value) {
    if (_brushTip == value) return;
    _brushTip = value;
    notifyListeners();
  }

  FillStyle get fillStyle => _fillStyle;

  set fillStyle(FillStyle value) {
    if (_fillStyle == value) return;
    _fillStyle = value;
    notifyListeners();
  }

  /// How far a pixel's colour may differ and still be filled, 0-255 per
  /// channel averaged.
  int get tolerance => _tolerance;

  set tolerance(int value) {
    final clamped = value.clamp(0, 255);
    if (_tolerance == clamped) return;
    _tolerance = clamped;
    notifyListeners();
  }

  /// True to fill only the connected region, false to fill every matching
  /// pixel in the image.
  bool get contiguous => _contiguous;

  set contiguous(bool value) {
    if (_contiguous == value) return;
    _contiguous = value;
    notifyListeners();
  }

  bool get antiAlias => _antiAlias;

  set antiAlias(bool value) {
    if (_antiAlias == value) return;
    _antiAlias = value;
    notifyListeners();
  }

  double get cornerRadius => _cornerRadius;

  set cornerRadius(double value) {
    final clamped = value.clamp(0.0, 200.0);
    if (_cornerRadius == clamped) return;
    _cornerRadius = clamped;
    notifyListeners();
  }

  /// When true the eraser paints the secondary colour instead of clearing to
  /// transparent, which is what classic Paint does.
  bool get eraseToSecondary => _eraseToSecondary;

  set eraseToSecondary(bool value) {
    if (_eraseToSecondary == value) return;
    _eraseToSecondary = value;
    notifyListeners();
  }

  /// When true, pixels matching the secondary colour are dropped from a
  /// selection when it is lifted or pasted.
  bool get selectionTransparent => _selectionTransparent;

  set selectionTransparent(bool value) {
    if (_selectionTransparent == value) return;
    _selectionTransparent = value;
    notifyListeners();
  }

  String get fontFamily => _fontFamily;

  set fontFamily(String value) {
    if (_fontFamily == value) return;
    _fontFamily = value;
    notifyListeners();
  }

  double get fontSize => _fontSize;

  set fontSize(double value) {
    final clamped = value.clamp(4.0, 512.0);
    if (_fontSize == clamped) return;
    _fontSize = clamped;
    notifyListeners();
  }

  bool get bold => _bold;

  set bold(bool value) {
    if (_bold == value) return;
    _bold = value;
    notifyListeners();
  }

  bool get italic => _italic;

  set italic(bool value) {
    if (_italic == value) return;
    _italic = value;
    notifyListeners();
  }

  bool get underline => _underline;

  set underline(bool value) {
    if (_underline == value) return;
    _underline = value;
    notifyListeners();
  }

  TextAlign get textAlign => _textAlign;

  set textAlign(TextAlign value) {
    if (_textAlign == value) return;
    _textAlign = value;
    notifyListeners();
  }

  bool get textOpaqueBackground => _textOpaqueBackground;

  set textOpaqueBackground(bool value) {
    if (_textOpaqueBackground == value) return;
    _textOpaqueBackground = value;
    notifyListeners();
  }
}
