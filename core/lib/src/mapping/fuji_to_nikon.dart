import '../model/colors.dart';
import '../model/fuji_meta.dart';
import '../model/mapping_report.dart';
import '../model/nikon_params.dart';
import 'target_profile.dart';

/// Converts a parsed Fujifilm film-simulation recipe into its best Nikon
/// Picture Control approximation, with a per-field fidelity report.
///
/// The product promise is "best Nikon translation", never "pixel-identical":
/// Fuji and Nikon use different sensors, color matrices and tone mapping.
/// Mapping version: [version].
abstract final class FujiToNikon {
  static const String version = 'fuji->np3:1';

  /// Film simulation -> suggested Nikon base Picture Control (informational;
  /// the base PC is chosen on the camera, the NP3 is the custom overlay).
  static Map<String, String> baseProfileHint(String? sim) {
    final s = (sim ?? '').toLowerCase();
    if (s.contains('velvia') || s.contains('provia') || s.contains('vivid')) {
      return {'hint': 'Vivid'};
    }
    if (s.contains('monochrome')) return {'hint': 'Monochrome'};
    if (s.contains('eterna') || s.contains('cinema')) return {'hint': 'Neutral'};
    if (s.contains('pro neg') || s.contains('reala') || s.contains('astia')) {
      return {'hint': 'Neutral'};
    }
    return {'hint': 'Standard'};
  }

  static (NikonParams, MappingReport) convert(
    FujiMeta f, {
    String? name,
    TargetProfile target = TargetProfile.z50ii,
  }) {
    final r = _Rep();

    // ---- saturation --------------------------------------------------------
    int? saturation;
    if (f.color != null && f.color != 0) {
      final v = (f.color! / 4 * 100).round().clamp(-100, 100);
      saturation = v;
      r.add('fuji.color', 'tone.saturation', _f(f.color), _f(v),
          MappingStatus.scaled, note: 'Fuji -4..+4 scaled x25 to Nikon -100..100');
    }

    // ---- detail --------------------------------------------------------------
    double? sharpening;
    if (f.sharpness != null && f.sharpness != 0) {
      final v = (f.sharpness! >= 0 ? f.sharpness! / 4 * 9 : f.sharpness! / 4 * 3)
          .clamp(-3.0, 9.0);
      sharpening = v;
      r.add('fuji.sharpness', 'detail.sharpening', _f(f.sharpness), _f(v),
          MappingStatus.approximated,
          note: "asymmetric: Fuji -4..+4 -> Nikon -3..9 (Nikon's range isn't symmetric)");
    }
    double? clarity;
    if (f.clarity != null && f.clarity != 0) {
      clarity = f.clarity!.clamp(-5.0, 5.0);
      r.add('fuji.clarity', 'detail.clarity', _f(f.clarity), _f(clarity),
          MappingStatus.exact, note: 'same -5..+5 range');
    }

    // ---- highlight / shadow tone -> NP3 sliders ------------------------------
    // Fuji highlight tone -2..+4, shadow tone -2..+4. DR200/DR400 protect
    // highlights via intentional underexposure+push, visually similar to a
    // gentler (negative) highlight setting, so we fold a small bias in.
    final dr = f.dynamicRange ?? 'DR100';
    final drBias = dr == 'DR200' ? -0.5 : (dr == 'DR400' ? -1.0 : 0.0);

    int? highlights;
    final hl = (f.highlightTone ?? 0) + drBias;
    if (hl != 0) {
      final v = (hl / 4 * 100).round().clamp(-100, 100);
      highlights = v;
      r.add('fuji.highlightTone+DR', 'tone.highlights', _f(hl), _f(v),
          MappingStatus.scaled,
          note: 'Fuji -2..+4 (+DR bias $drBias) scaled to Nikon -100..100');
    } else if (f.highlightTone != null) {
      r.ignored('fuji.highlightTone', 'value is at default');
    }

    int? shadows;
    final sh = f.shadowTone ?? 0;
    if (sh != 0) {
      final v = (sh / 4 * 100).round().clamp(-100, 100);
      shadows = v;
      r.add('fuji.shadowTone', 'tone.shadows', _f(sh), _f(v),
          MappingStatus.scaled, note: 'Fuji -2..+4 scaled to Nikon -100..100');
    }

    // ---- color chrome effect -> color blender --------------------------------
    final blender = <String, ColorChannel>{};
    _chrome(r, f.colorChromeEffect, (weak, strong) {
      blender['red'] = ColorChannel(chroma: weak ? 10 : 20);
      blender['orange'] = ColorChannel(chroma: weak ? 5 : 10);
    });
    _chrome(r, f.colorChromeEffectBlue, (weak, strong) {
      blender['blue'] = ColorChannel(chroma: weak ? 10 : 20, brightness: weak ? -5 : -10);
      blender['cyan'] = ColorChannel(chroma: weak ? 5 : 10);
    });

    // ---- WB shift -> midtone tint (approx) ------------------------------------
    final grading = <String, GradingZone>{};
    final red = f.wbRedShift ?? 0;
    final blue = f.wbBlueShift ?? 0;
    final warmth = (red - blue) / 2;
    if (warmth.abs() >= 0.5) {
      final hue = warmth > 0 ? 35 : 205;
      final chroma = (warmth.abs() * 3).clamp(0, 40).round();
      grading['midtones'] = GradingZone(hue: hue, chroma: chroma, brightness: 0);
      r.add('fuji.wbShift', 'color.colorGrading.midtones',
          'R $red / B $blue', 'hue $hue chroma $chroma',
          MappingStatus.approximated,
          note: 'WB mode itself is a camera setting; only the R/B shift is approximated as a midtone tint');
    }

    // ---- base profile hint ------------------------------------------------------
    final hint = baseProfileHint(f.filmSimulation)['hint'] ?? '';
    if (f.filmSimulation != null) {
      r.note('fuji.filmSimulation', 'baseProfileHint', f.filmSimulation!, hint,
          'base Picture Control is chosen on the camera; NP3 is the custom overlay');
    }

    // ---- unsupported ------------------------------------------------------------
    if (f.grainStrength != null && f.grainStrength!.toLowerCase() != 'off') {
      r.unsupported('fuji.grainEffect', 'film grain has no NP3 equivalent (set in post)');
    }
    if (f.noiseReduction != null && f.noiseReduction != 0) {
      r.unsupported('fuji.noiseReduction', 'noise reduction is a camera setting');
    }
    if (f.iso != null) {
      r.unsupported('fuji.iso', 'ISO is a camera setting');
    }
    if (f.exposureComp != null && f.exposureComp!.trim() != '0') {
      r.unsupported('fuji.exposureComp', 'exposure compensation is a camera setting');
    }
    if (f.whiteBalanceMode != null) {
      r.unsupported('fuji.whiteBalanceMode', 'WB mode is a camera setting; only the R/B shift is approximated');
    }

    final nikon = NikonParams(
      name: name,
      saturation: saturation,
      sharpening: sharpening,
      clarity: clarity,
      highlights: highlights,
      shadows: shadows,
      colorBlender: blender.isEmpty ? null : blender,
      colorGrading: grading.isEmpty ? null : grading,
      baseProfileHint: hint,
    );

    final report = MappingReport(
      sourceFormat: 'fujiText',
      target: target.name,
      fields: r.fields,
      mappingVersion: version,
    );
    return (nikon, report);
  }

  static void _chrome(
      _Rep r, String? value, void Function(bool weak, bool strong) apply) {
    final label = value ?? 'off';
    switch (label.toLowerCase()) {
      case 'weak':
        r.add('fuji.colorChrome($label)', 'color.colorBlender', label, 'weak',
            MappingStatus.approximated,
            note: 'flat per-channel chroma boost approximates Color Chrome');
        apply(true, false);
      case 'strong':
        r.add('fuji.colorChrome($label)', 'color.colorBlender', label, 'strong',
            MappingStatus.approximated,
            note: 'flat per-channel chroma boost approximates Color Chrome');
        apply(false, true);
      default:
        break;
    }
  }

  static String _f(num? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2));
}

class _Rep {
  final List<FieldMapping> fields = [];

  void add(String src, String tgt, String sv, String tv, MappingStatus s,
      {String? note}) {
    fields.add(FieldMapping(
        sourceField: src,
        targetField: tgt,
        sourceValue: sv,
        targetValue: tv,
        status: s,
        note: note));
  }

  void note(String src, String tgt, String sv, String tv, String? note) {
    fields.add(FieldMapping(
        sourceField: src,
        targetField: tgt,
        sourceValue: sv,
        targetValue: tv,
        status: MappingStatus.approximated,
        note: note));
  }

  void unsupported(String src, String? note) {
    fields.add(FieldMapping(
        sourceField: src,
        targetField: '',
        sourceValue: '',
        targetValue: null,
        status: MappingStatus.unsupported,
        note: note));
  }

  void ignored(String src, String? note) {
    fields.add(FieldMapping(
        sourceField: src,
        targetField: '',
        sourceValue: '',
        targetValue: null,
        status: MappingStatus.ignored,
        note: note));
  }
}