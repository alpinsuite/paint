import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slate_ui/slate_ui.dart';

import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

/// Opens the colour editor and returns the chosen colour, or null on cancel.
Future<Color?> showColorPickerDialog(BuildContext context, Color initial) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(initial: initial),
  );
}

/// Saturation/value square, hue and alpha sliders, and RGB/hex entry.
///
/// Hand-rolled rather than pulled from a package: the picker is small, and this
/// way it inherits the app's sober theme instead of importing another one.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hexController;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hexController = TextEditingController(text: _toHex(widget.initial));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _setColor(Color color, {bool syncHex = true}) {
    setState(() {
      // Preserve hue when the colour is achromatic, or dragging into pure
      // black would reset the hue slider to red on the way back out.
      final converted = HSVColor.fromColor(color);
      _hsv = converted.saturation == 0
          ? converted.withHue(_hsv.hue)
          : converted;
      if (syncHex) _hexController.text = _toHex(color);
      _hexError = null;
    });
  }

  void _setHsv(HSVColor value) {
    setState(() {
      _hsv = value;
      _hexController.text = _toHex(value.toColor());
      _hexError = null;
    });
  }

  static String _toHex(Color color) {
    final argb = color.toARGB32();
    final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#${rgb.toUpperCase()}';
  }

  void _applyHex(String raw) {
    final text = raw.trim().replaceFirst('#', '');
    final value = int.tryParse(text, radix: 16);
    if (value == null || (text.length != 6 && text.length != 8)) {
      setState(() => _hexError = AppLocalizations.of(context).colorInvalidHex);
      return;
    }
    final argb = text.length == 6 ? 0xFF000000 | value : value;
    _setColor(Color(argb), syncHex: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = _color;

    return SlateDialog(
      title: l10n.colorDialogTitle,
      width: 420,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 170,
              child: _SaturationValueBox(
                hsv: _hsv,
                onChanged: (saturation, value) =>
                    _setHsv(_hsv.withSaturation(saturation).withValue(value)),
              ),
            ),
            const SizedBox(height: 14),
            _ChannelSlider(
              label: l10n.colorHue,
              value: _hsv.hue,
              max: 360,
              gradient: const <Color>[
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
              onChanged: (value) => _setHsv(_hsv.withHue(value)),
            ),
            _ChannelSlider(
              label: l10n.colorAlpha,
              value: _hsv.alpha * 255,
              max: 255,
              gradient: <Color>[color.withAlpha(0), color.withAlpha(255)],
              onChanged: (value) => _setHsv(_hsv.withAlpha(value / 255)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: SlateSeparator(),
            ),
            _ChannelSlider(
              label: l10n.colorRed,
              value: (color.r * 255).roundToDouble(),
              max: 255,
              gradient: <Color>[color.withRed(0), color.withRed(255)],
              onChanged: (value) => _setColor(color.withRed(value.round())),
            ),
            _ChannelSlider(
              label: l10n.colorGreen,
              value: (color.g * 255).roundToDouble(),
              max: 255,
              gradient: <Color>[color.withGreen(0), color.withGreen(255)],
              onChanged: (value) => _setColor(color.withGreen(value.round())),
            ),
            _ChannelSlider(
              label: l10n.colorBlue,
              value: (color.b * 255).roundToDouble(),
              max: 255,
              gradient: <Color>[color.withBlue(0), color.withBlue(255)],
              onChanged: (value) => _setColor(color.withBlue(value.round())),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _Preview(color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: SlateLabeledField(
                    label: _hexError ?? l10n.colorHex,
                    child: SlateField(
                      controller: _hexController,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                          RegExp('[#0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(9),
                      ],
                      onSubmitted: _applyHex,
                      onChanged: (value) {
                        if (value.replaceFirst('#', '').length >= 6) {
                          _applyHex(value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        SlateButton(
          label: l10n.buttonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SlateButton(
          kind: SlateButtonKind.primary,
          label: l10n.buttonOk,
          onPressed: () => Navigator.of(context).pop(_color),
        ),
      ],
    );
  }
}

/// Saturation left-to-right, value bottom-to-top, for the current hue.
class _SaturationValueBox extends StatelessWidget {
  const _SaturationValueBox({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final void Function(double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void handle(Offset local) {
          onChanged(
            (local.dx / constraints.maxWidth).clamp(0.0, 1.0),
            1 - (local.dy / constraints.maxHeight).clamp(0.0, 1.0),
          );
        }

        return GestureDetector(
          onPanDown: (details) => handle(details.localPosition),
          onPanUpdate: (details) => handle(details.localPosition),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.white,
                        HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[Colors.black, Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: hsv.saturation * constraints.maxWidth - 6,
                top: (1 - hsv.value) * constraints.maxHeight - 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black54, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.gradient,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final List<Color> gradient;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: <Widget>[
          SizedBox(width: 68, child: Text(label, style: theme.dimTextStyle)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 10,
                // The gradient is the track, so the thumb needs to sit on top
                // of it without an opaque active/inactive split.
                activeTrackColor: const Color(0x00000000),
                inactiveTrackColor: const Color(0x00000000),
                overlayColor: theme.palette.accent.withValues(alpha: 0.14),
                thumbColor: const Color(0xFFFFFFFF),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                  elevation: 1,
                  pressedElevation: 1,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(colors: gradient),
                      border: Border.all(color: theme.palette.fieldBorder),
                    ),
                  ),
                  Slider(
                    value: value.clamp(0, max),
                    max: max,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${value.round()}',
              textAlign: TextAlign.right,
              style: theme.dimTextStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final canvasColors = context.canvasColors;
    return Container(
      width: 54,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: canvasColors.handleBorder),
        color: canvasColors.checkerLight,
      ),
      child: Container(color: color),
    );
  }
}
