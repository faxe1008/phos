import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../preview/nikon_filter.dart';
import '../state/app_model.dart';
import '../theme/app_theme.dart';
import '../widgets/compare_preview_box.dart';
import '../widgets/color_wheel.dart';
import '../widgets/tone_curve_editor.dart';

/// Edit the Nikon projection of a style (always a user copy — the original
/// is immutable) with a live preview.
class StyleEditorScreen extends StatefulWidget {
  const StyleEditorScreen({
    super.key,
    required this.model,
    required this.recipe,
  });

  final AppModel model;
  final UniversalRecipe recipe;

  @override
  State<StyleEditorScreen> createState() => _StyleEditorScreenState();
}

class _StyleEditorScreenState extends State<StyleEditorScreen> {
  late final TextEditingController _nameCtrl;
  late NikonParams _nikon;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.recipe.name);
    _nikon = widget.recipe.nikon;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _update(NikonParams Function(NikonParams p) fn) {
    setState(() => _nikon = fn(_nikon));
  }

  void _reset() {
    // Neutral sliders, but keep the tone curve: it is the style's
    // character. The curve can be removed from its own section.
    _update((p) => NikonParams(toneCurve: p.toneCurve));
  }

  List<Point> get _curvePoints {
    final c = _nikon.toneCurve;
    if (c == null) return const [];
    return c.points.where((p) => p.x > 0 && p.x < 255).toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  void _setCurve(List<Point> pts) {
    _update((p) => p.copyWith(toneCurve: CurveBuilder.fromControlPoints(pts)));
  }

  void _removeCurve() {
    _update((p) => p.copyWith(toneCurve: null));
  }

  bool get _hasGrading =>
      (_nikon.colorGrading?.values.any((z) => !z.isNeutral) ?? false) ||
      (_nikon.gradingBlending ?? 50) != 50 ||
      (_nikon.gradingBalance ?? 0) != 0;

  void _setZone(String zone, {int? hue, int? chroma, int? brightness}) {
    final zones = <String, GradingZone>{
      for (final n in GradingZone.zoneNames)
        n: _nikon.colorGrading?[n] ?? const GradingZone(),
    };
    final z = zones[zone]!;
    zones[zone] = GradingZone(
      hue: hue ?? z.hue,
      chroma: chroma ?? z.chroma,
      brightness: brightness ?? z.brightness,
    );
    _update((p) => p.copyWith(colorGrading: zones));
  }

  void _resetGrading() {
    _update(
      (p) => p.copyWith(
        colorGrading: const {
          'highlights': GradingZone(),
          'midtones': GradingZone(),
          'shadows': GradingZone(),
        },
        gradingBlending: 50,
        gradingBalance: 0,
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final saved = widget.recipe
      ..name = name.isEmpty ? widget.recipe.name : name
      ..nikon = _nikon;
    widget.model.saveEdited(saved);
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final hasBlender =
        _nikon.colorBlender != null &&
        _nikon.colorBlender!.values.any((c) => !c.isNeutral);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit style'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Neutral', style: TextStyle(fontSize: 13)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.seed,
              foregroundColor: const Color(0xFF1A1205),
            ),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ComparePreviewBox(
            service: widget.model.preview,
            baseJpeg: widget.model.baseJpeg,
            params: _nikon,
            // Smaller than the detail screen so slider drags stay snappy.
            width: 480,
            version: widget.model.previewVersion,
            borderRadius: 20,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: const TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          const SizedBox(height: 14),
          _curveSection(),
          const SizedBox(height: 14),
          _gradingSection(),
          const SizedBox(height: 8),
          _slider(
            'Contrast',
            _nikon.contrast ?? 0,
            -100,
            100,
            200,
            (_nikon.contrast ?? 0).toString(),
            (v) => _update((p) => p.copyWith(contrast: v.round())),
          ),
          _slider(
            'Highlights',
            _nikon.highlights ?? 0,
            -100,
            100,
            200,
            (_nikon.highlights ?? 0).toString(),
            (v) => _update((p) => p.copyWith(highlights: v.round())),
          ),
          _slider(
            'Shadows',
            _nikon.shadows ?? 0,
            -100,
            100,
            200,
            (_nikon.shadows ?? 0).toString(),
            (v) => _update((p) => p.copyWith(shadows: v.round())),
          ),
          _slider(
            'White level',
            _nikon.whiteLevel ?? 0,
            -100,
            100,
            200,
            (_nikon.whiteLevel ?? 0).toString(),
            (v) => _update((p) => p.copyWith(whiteLevel: v.round())),
          ),
          _slider(
            'Black level',
            _nikon.blackLevel ?? 0,
            -100,
            100,
            200,
            (_nikon.blackLevel ?? 0).toString(),
            (v) => _update((p) => p.copyWith(blackLevel: v.round())),
          ),
          _slider(
            'Saturation',
            _nikon.saturation ?? 0,
            -100,
            100,
            200,
            (_nikon.saturation ?? 0).toString(),
            (v) => _update((p) => p.copyWith(saturation: v.round())),
          ),
          _slider(
            'Sharpening',
            _nikon.sharpening ?? NikonParams.defaultSharpening,
            -3,
            9,
            48,
            (_nikon.sharpening ?? NikonParams.defaultSharpening)
                .toStringAsFixed(2),
            (v) => _update((p) => p.copyWith(sharpening: v)),
          ),
          _slider(
            'Mid-range sharpening',
            _nikon.midRangeSharpening ?? NikonParams.defaultMidRangeSharpening,
            -5,
            5,
            40,
            (_nikon.midRangeSharpening ?? NikonParams.defaultMidRangeSharpening)
                .toStringAsFixed(2),
            (v) => _update((p) => p.copyWith(midRangeSharpening: v)),
          ),
          _slider(
            'Clarity',
            _nikon.clarity ?? NikonParams.defaultClarity,
            -5,
            5,
            40,
            (_nikon.clarity ?? NikonParams.defaultClarity).toStringAsFixed(2),
            (v) => _update((p) => p.copyWith(clarity: v)),
          ),
          if (hasBlender) ...[
            const SizedBox(height: 14),
            _notice(
              'Color channels (blender) are carried over from the '
              'original style (not editable yet).',
            ),
          ],
        ],
      ),
    );
  }

  Widget _curveSection() {
    final hasCurve = _nikon.hasToneCurve;
    final size = 200.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tone curve',
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                ),
              ),
              Text(
                hasCurve
                    ? 'on the camera this overrides the sliders below'
                    : 'tap to add a point',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              ),
              if (hasCurve)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Remove curve',
                  onPressed: _removeCurve,
                ),
            ],
          ),
          Center(
            child: ToneCurveEditor(
              points: _curvePoints,
              onChanged: _setCurve,
              size: size,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradingSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Color grading',
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                ),
              ),
              if (_hasGrading)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Reset grading',
                  onPressed: _resetGrading,
                ),
            ],
          ),
          for (final zone in GradingZone.zoneNames) _gradingRow(zone),
          const SizedBox(height: 4),
          _slider(
            'Blending',
            _nikon.gradingBlending ?? 50,
            0,
            100,
            100,
            (_nikon.gradingBlending ?? 50).toString(),
            (v) => _update((p) => p.copyWith(gradingBlending: v.round())),
          ),
          _slider(
            'Balance',
            _nikon.gradingBalance ?? 0,
            -100,
            100,
            200,
            (_nikon.gradingBalance ?? 0).toString(),
            (v) => _update((p) => p.copyWith(gradingBalance: v.round())),
          ),
        ],
      ),
    );
  }

  Widget _gradingRow(String zone) {
    final z = _nikon.colorGrading?[zone] ?? const GradingZone();
    final deg = z.hue * 360.0 / 4096;
    final sat = (z.chroma.abs() / 100.0).clamp(0.0, 1.0);
    final (tr, tg, tb) = hslToRgb(deg, sat, 0.5);
    final label = zone[0].toUpperCase() + zone.substring(1);
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(
                  255,
                  (tr * 255).round(),
                  (tg * 255).round(),
                  (tb * 255).round(),
                ),
                border: Border.all(color: AppTheme.hairline),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              z.isNeutral ? 'neutral' : '${z.chroma.abs()}% chroma',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
        Center(
          child: ColorWheel(
            key: ValueKey('color-wheel-$zone'),
            hue: deg,
            chroma: z.chroma.abs().toDouble(),
            onChanged: (value) => _setZone(
              zone,
              hue: (value.hue / 360 * 4096).round() % 4096,
              chroma: value.chroma.round(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${deg.round()}\u00B0 hue  ·  ${z.chroma.abs()}% chroma',
            style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
        ),
        _slider(
          'Chroma',
          z.chroma.toDouble(),
          -100,
          100,
          200,
          z.chroma.toString(),
          (v) => _setZone(zone, chroma: v.round()),
        ),
        _slider(
          'Brightness',
          z.brightness.toDouble(),
          -100,
          100,
          200,
          z.brightness.toString(),
          (v) => _setZone(zone, brightness: v.round()),
        ),
      ],
    );
  }

  Widget _notice(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textTertiary,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    num value,
    double min,
    double max,
    int divisions,
    String valueText,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble().clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
