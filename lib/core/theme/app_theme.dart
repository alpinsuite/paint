import 'package:flutter/material.dart';
import 'package:slate_ui/slate_ui.dart';

/// Colours the editor needs that no interface kit can supply.
///
/// These describe the drawing surface rather than the chrome — the backdrop
/// behind the image, the transparency checkerboard, the marching ants. They are
/// specific to an image editor, which is exactly why they live here and not in
/// [SlatePalette].
@immutable
class CanvasColors extends ThemeExtension<CanvasColors> {
  const CanvasColors({
    required this.backdrop,
    required this.checkerLight,
    required this.checkerDark,
    required this.canvasBorder,
    required this.marchingAntsLight,
    required this.marchingAntsDark,
    required this.handleFill,
    required this.handleBorder,
  });

  /// Area around the image.
  final Color backdrop;

  /// The two squares of the transparency checkerboard.
  final Color checkerLight;
  final Color checkerDark;

  /// Hairline around the image bounds.
  final Color canvasBorder;

  /// The two dash colours of the selection outline. They alternate so the
  /// outline stays visible over both light and dark pixels.
  final Color marchingAntsLight;
  final Color marchingAntsDark;

  /// Selection resize handles.
  final Color handleFill;
  final Color handleBorder;

  static const CanvasColors light = CanvasColors(
    backdrop: Color(0xFFE8E9EB),
    checkerLight: Color(0xFFFFFFFF),
    checkerDark: Color(0xFFD6D8DB),
    canvasBorder: Color(0x33000000),
    marchingAntsLight: Color(0xFFFFFFFF),
    marchingAntsDark: Color(0xFF000000),
    handleFill: Color(0xFFFFFFFF),
    handleBorder: Color(0xFF3F4A5A),
  );

  static const CanvasColors dark = CanvasColors(
    backdrop: Color(0xFF1B1D20),
    checkerLight: Color(0xFF4A4D52),
    checkerDark: Color(0xFF3A3D42),
    canvasBorder: Color(0x55FFFFFF),
    marchingAntsLight: Color(0xFFFFFFFF),
    marchingAntsDark: Color(0xFF000000),
    handleFill: Color(0xFF23262A),
    handleBorder: Color(0xFFC9CDD4),
  );

  @override
  CanvasColors copyWith({
    Color? backdrop,
    Color? checkerLight,
    Color? checkerDark,
    Color? canvasBorder,
    Color? marchingAntsLight,
    Color? marchingAntsDark,
    Color? handleFill,
    Color? handleBorder,
  }) {
    return CanvasColors(
      backdrop: backdrop ?? this.backdrop,
      checkerLight: checkerLight ?? this.checkerLight,
      checkerDark: checkerDark ?? this.checkerDark,
      canvasBorder: canvasBorder ?? this.canvasBorder,
      marchingAntsLight: marchingAntsLight ?? this.marchingAntsLight,
      marchingAntsDark: marchingAntsDark ?? this.marchingAntsDark,
      handleFill: handleFill ?? this.handleFill,
      handleBorder: handleBorder ?? this.handleBorder,
    );
  }

  @override
  CanvasColors lerp(ThemeExtension<CanvasColors>? other, double t) {
    if (other is! CanvasColors) return this;
    return CanvasColors(
      backdrop: Color.lerp(backdrop, other.backdrop, t)!,
      checkerLight: Color.lerp(checkerLight, other.checkerLight, t)!,
      checkerDark: Color.lerp(checkerDark, other.checkerDark, t)!,
      canvasBorder: Color.lerp(canvasBorder, other.canvasBorder, t)!,
      marchingAntsLight: Color.lerp(
        marchingAntsLight,
        other.marchingAntsLight,
        t,
      )!,
      marchingAntsDark: Color.lerp(
        marchingAntsDark,
        other.marchingAntsDark,
        t,
      )!,
      handleFill: Color.lerp(handleFill, other.handleFill, t)!,
      handleBorder: Color.lerp(handleBorder, other.handleBorder, t)!,
    );
  }
}

/// The editor's chrome, which is the Slate kit plus the canvas colours.
///
/// Everything about how a control looks lives in [SlateThemeData]; this class
/// only picks the palette for a brightness and attaches the drawing-surface
/// colours the kit has no opinion about. Keeping that split means the kit can
/// be lifted into its own package without unpicking the application from it.
abstract final class AppTheme {
  static const SlateThemeData lightSlate = SlateThemeData.light();
  static const SlateThemeData darkSlate = SlateThemeData.dark();

  /// A tool-palette button. Larger than the controls in a bar, because these
  /// are the targets the user hits most and they are the only icons in the
  /// window carrying meaning on their own.
  static const double toolButtonSize = 30;

  static SlateThemeData slateFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSlate : lightSlate;

  static ThemeData light() => _build(lightSlate, CanvasColors.light);

  static ThemeData dark() => _build(darkSlate, CanvasColors.dark);

  /// Material still supplies Scaffold, Navigator, dialogs and text selection,
  /// so its theme has to agree with the kit rather than sit beside it.
  static ThemeData _build(SlateThemeData slate, CanvasColors canvas) {
    return slate.toMaterialTheme().copyWith(
      extensions: <ThemeExtension<dynamic>>[canvas],
    );
  }
}

/// Convenience access to [CanvasColors] from a [BuildContext].
extension CanvasColorsContext on BuildContext {
  CanvasColors get canvasColors =>
      Theme.of(this).extension<CanvasColors>() ?? CanvasColors.light;
}
