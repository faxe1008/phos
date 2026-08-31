import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../state/app_model.dart';
import '../theme/app_theme.dart';
import '../widgets/compare_preview_box.dart';

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
    // character and has no editor yet.
    _update((p) => NikonParams(toneCurve: p.toneCurve));
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
    final hasCurve = _nikon.hasToneCurve;
    final hasColor = (_nikon.colorBlender != null &&
            _nikon.colorBlender!.values.any((c) => !c.isNeutral)) ||
        (_nikon.colorGrading != null &&
            _nikon.colorGrading!.values.any((z) => !z.isNeutral));
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
            style:
                const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: const TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          if (hasCurve) ...[
            const SizedBox(height: 14),
            _notice(
              'This style uses a custom tone curve. On the camera it '
              'overrides the tonal sliders below; the curve itself is '
              'not editable yet.',
            ),
          ],
          const SizedBox(height: 8),
          _slider(
            'Contrast',
            _nikon.contrast ?? 0,
            -100, 100, 200,
            (_nikon.contrast ?? 0).toString(),
            (v) => _update((p) => p.copyWith(contrast: v.round())),
          ),
          _slider(
            'Highlights',
            _nikon.highlights ?? 0,
            -100, 100, 200,
            (_nikon.highlights ?? 0).toString(),
            (v) => _update((p) => p.copyWith(highlights: v.round())),
          ),
          _slider(
            'Shadows',
            _nikon.shadows ?? 0,
            -100, 100, 200,
            (_nikon.shadows ?? 0).toString(),
            (v) => _update((p) => p.copyWith(shadows: v.round())),
          ),
          _slider(
            'White level',
            _nikon.whiteLevel ?? 0,
            -100, 100, 200,
            (_nikon.whiteLevel ?? 0).toString(),
            (v) => _update((p) => p.copyWith(whiteLevel: v.round())),
          ),
          _slider(
            'Black level',
            _nikon.blackLevel ?? 0,
            -100, 100, 200,
            (_nikon.blackLevel ?? 0).toString(),
            (v) => _update((p) => p.copyWith(blackLevel: v.round())),
          ),
          _slider(
            'Saturation',
            _nikon.saturation ?? 0,
            -100, 100, 200,
            (_nikon.saturation ?? 0).toString(),
            (v) => _update((p) => p.copyWith(saturation: v.round())),
          ),
          _slider(
            'Sharpening',
            _nikon.sharpening ?? NikonParams.defaultSharpening,
            -3, 9, 48,
            (_nikon.sharpening ?? NikonParams.defaultSharpening)
                .toStringAsFixed(2),
            (v) => _update((p) => p.copyWith(sharpening: v)),
          ),
          _slider(
            'Mid-range sharpening',
            _nikon.midRangeSharpening ?? NikonParams.defaultMidRangeSharpening,
            -5, 5, 40,
            (_nikon.midRangeSharpening ?? NikonParams.defaultMidRangeSharpening)
                .toStringAsFixed(2),
            (v) => _update((p) => p.copyWith(midRangeSharpening: v)),
          ),
          _slider(
            'Clarity',
            _nikon.clarity ?? NikonParams.defaultClarity,
            -5, 5, 40,
            (_nikon.clarity ?? NikonParams.defaultClarity).toStringAsFixed(2),
            (v) => _update((p) => p.copyWith(clarity: v)),
          ),
          _slider(
            'Split-tone balance',
            _nikon.gradingBalance ?? 0,
            -100, 100, 200,
            (_nikon.gradingBalance ?? 0).toString(),
            (v) => _update((p) => p.copyWith(gradingBalance: v.round())),
          ),
          _slider(
            'Split-tone blending',
            _nikon.gradingBlending ?? 50,
            0, 100, 100,
            (_nikon.gradingBlending ?? 50).toString(),
            (v) => _update((p) => p.copyWith(gradingBlending: v.round())),
          ),
          if (hasColor) ...[
            const SizedBox(height: 14),
            _notice(
              'Color channels and split-toning colors are carried over '
              'from the original style (not editable yet).',
            ),
          ],
        ],
      ),
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
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textTertiary, height: 1.5)),
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
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textPrimary)),
              ),
              Text(valueText,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontFeatures: [
                        FontFeature.tabularFigures()
                      ])),
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