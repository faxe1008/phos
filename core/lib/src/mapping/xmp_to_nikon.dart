import '../model/colors.dart';
import '../model/mapping_report.dart';
import '../model/nikon_params.dart';
import '../model/xmp_meta.dart';
import 'curve_builder.dart';
import 'target_profile.dart';

/// Converts a parsed Lightroom XMP preset into its best Nikon Picture
/// Control approximation, with a per-field fidelity report.
///
/// Mapping version: [version]. Bump when any formula changes.
abstract final class XmpToNikon {
  static const String version = 'xmp->np3:1';

  static (NikonParams, MappingReport) convert(
    XmpMeta m, {
    String? name,
    TargetProfile target = TargetProfile.z50ii,
  }) {
    final r = _Report();
    final pv = (m.processVersion ?? 2) >= 2;

    // ---- tonal sliders (1:1 or rescaled) ---------------------------------
    int? contrast;
    if (m.contrast != null) {
      final v = (pv ? m.contrast! * (100.0 / 150.0) : m.contrast! * 2.0).round();
      contrast = _clamp(v, target);
      r.add('xmp.contrast', 'tone.contrast', _f(m.contrast), _f(contrast),
          pv ? MappingStatus.scaled : MappingStatus.scaled,
          note: pv ? 'LR -150..150 scaled x(100/150)' : 'LR -50..50 scaled x2');
    }
    int? highlights = _tone1to1('xmp.highlights', 'highlights', m.highlights, r, target);
    int? shadows = _tone1to1('xmp.shadows', 'shadows', m.shadows, r, target);
    int? whiteLevel = _tone1to1('xmp.whites', 'whiteLevel', m.whites, r, target);
    int? blackLevel = _tone1to1('xmp.blacks', 'blackLevel', m.blacks, r, target);

    // ---- saturation (1:1) + vibrance (approx 50%) ------------------------
    int? saturation;
    if (m.saturation != null) {
      saturation = _clamp(m.saturation!.round(), target);
      r.add('xmp.saturation', 'tone.saturation', _f(m.saturation), _f(saturation),
          MappingStatus.exact);
    }
    if (m.vibrance != null && m.vibrance != 0) {
      final add = (m.vibrance! * 0.5).round();
      saturation = _clamp((saturation ?? 0) + add, target);
      r.add('xmp.vibrance', 'tone.saturation', _f(m.vibrance), _f(add),
          MappingStatus.approximated,
          note: 'folded into saturation at 50% weight (no vibrance in NP3)');
    }

    // ---- detail ------------------------------------------------------------
    double? sharpening;
    if (m.sharpenDetail != null) {
      sharpening = (m.sharpenDetail! / 100.0 * 9.0).clamp(-3.0, 9.0);
      r.add('xmp.sharpenDetail', 'detail.sharpening', _f(m.sharpenDetail),
          _f(sharpening), MappingStatus.scaled,
          note: '0..100 scaled to Nikon 0..9');
    } else if (m.sharpening != null) {
      final v = m.sharpening!;
      sharpening = (v >= 0 ? v / 300.0 * 9.0 : v / 300.0 * 3.0)
          .clamp(-3.0, 9.0);
      r.add('xmp.sharpening', 'detail.sharpening', _f(v), _f(sharpening),
          MappingStatus.approximated, note: 'legacy LR sharpening approximated');
    }
    double? clarity;
    if (m.clarity != null && m.clarity != 0) {
      clarity = (m.clarity! / 20.0).clamp(-5.0, 5.0);
      r.add('xmp.clarity', 'detail.clarity', _f(m.clarity), _f(clarity),
          MappingStatus.scaled, note: 'LR -100..100 scaled to Nikon -5..5');
    }
    _maybeUnsupported(r, 'xmp.texture', m.texture,
        'Texture has no NP3 equivalent');
    _maybeUnsupported(r, 'xmp.dehaze', m.dehaze, 'Dehaze has no NP3 equivalent');
    _maybeUnsupported(r, 'xmp.sharpenRadius', m.sharpenRadius,
        'radius affects sharpening algorithm only');
    _maybeUnsupported(r, 'xmp.sharpenEdgeMasking', m.sharpenEdgeMasking,
        'edge masking has no NP3 equivalent');

    // ---- color: HSL -> color blender --------------------------------------
    final blender = <String, ColorChannel>{};
    final hueScale = 100.0 / 180.0;
    const xmpHue = [
      (XmpHslColor.red, 'red'),
      (XmpHslColor.orange, 'orange'),
      (XmpHslColor.yellow, 'yellow'),
      (XmpHslColor.green, 'green'),
      (XmpHslColor.aqua, 'cyan'),
      (XmpHslColor.blue, 'blue'),
      (XmpHslColor.purple, 'purple'),
      (XmpHslColor.magenta, 'magenta'),
    ];
    for (final (xc, nikonName) in xmpHue) {
      final adj = m.hsl?[xc];
      if (adj == null) continue;
      int? hue, chroma, lum;
      var touched = false;
      if (adj.hue != null && adj.hue != 0) {
        hue = _clamp((adj.hue! * hueScale).round(), target);
        r.add('xmp.hsl.$nikonName.hue', 'color.colorBlender.$nikonName.hue',
            _f(adj.hue), _f(hue),
            (adj.hue! * hueScale).abs() > 100 ? MappingStatus.clamped : MappingStatus.scaled,
            note: 'LR -180..180 scaled to NP3 -100..100');
        touched = true;
      }
      if (adj.saturation != null && adj.saturation != 0) {
        chroma = _clamp(adj.saturation!.round(), target);
        r.add('xmp.hsl.$nikonName.saturation', 'color.colorBlender.$nikonName.chroma',
            _f(adj.saturation), _f(chroma), MappingStatus.exact);
        touched = true;
      }
      if (adj.luminance != null && adj.luminance != 0) {
        lum = _clamp(adj.luminance!.round(), target);
        r.add('xmp.hsl.$nikonName.luminance', 'color.colorBlender.$nikonName.brightness',
            _f(adj.luminance), _f(lum), MappingStatus.exact);
        touched = true;
      }
      if (touched) {
        blender[nikonName] =
            ColorChannel(hue: hue ?? 0, chroma: chroma ?? 0, brightness: lum ?? 0);
      }
    }

    // ---- color grading (new) or split toning (legacy) ---------------------
    final grading = <String, GradingZone>{};
    int? blending;
    int? balance;

    void zoneFromCg(
        String nikonZone, XmpColorGradeZone? z, _Report rep) {
      if (z == null) return;
      int? hue, chroma, lum;
      var touched = false;
      if (z.hue != null && z.hue != 0) {
        hue = z.hue!.round().clamp(0, 360);
        rep.add('xmp.colorGrade.$nikonZone.hue', 'color.colorGrading.$nikonZone.hue',
            _f(z.hue), _f(hue), MappingStatus.exact);
        touched = true;
      }
      if (z.saturation != null && z.saturation != 50) {
        chroma = _clamp(((z.saturation! - 50) * 2).round(), target);
        rep.add('xmp.colorGrade.$nikonZone.saturation',
            'color.colorGrading.$nikonZone.chroma', _f(z.saturation), _f(chroma),
            MappingStatus.scaled, note: 'LR 0..100 recentered to NP3 -100..100');
        touched = true;
      }
      if (z.luminance != null && z.luminance != 0) {
        lum = _clamp(z.luminance!.round(), target);
        rep.add('xmp.colorGrade.$nikonZone.luminance',
            'color.colorGrading.$nikonZone.brightness', _f(z.luminance), _f(lum),
            MappingStatus.exact);
        touched = true;
      }
      if (touched) {
        grading[nikonZone] =
            GradingZone(hue: hue ?? 0, chroma: chroma ?? 0, brightness: lum ?? 0);
      }
    }

    final hasNewCg = m.colorGradeHigh != null ||
        m.colorGradeMid != null ||
        m.colorGradeShadow != null;
    if (hasNewCg) {
      zoneFromCg('highlights', m.colorGradeHigh, r);
      zoneFromCg('midtones', m.colorGradeMid, r);
      zoneFromCg('shadows', m.colorGradeShadow, r);
      if (m.colorGradeBlending != null && m.colorGradeBlending != 50) {
        blending = _clamp(m.colorGradeBlending!.round(), target);
        r.add('xmp.colorGradeBlending', 'color.gradingBlending',
            _f(m.colorGradeBlending), _f(blending), MappingStatus.exact);
      }
      if (m.colorGradeBalance != null && m.colorGradeBalance != 0) {
        balance = _clamp(m.colorGradeBalance!.round(), target);
        r.add('xmp.colorGradeBalance', 'color.gradingBalance',
            _f(m.colorGradeBalance), _f(balance), MappingStatus.exact);
      }
      _maybeUnsupported(r, 'xmp.colorGradeGlobalSaturation',
          m.colorGradeGlobalSaturation, 'global grading saturation has no NP3 control');
    } else {
      // Legacy split toning.
      _splitZone(r, 'shadows', m.splitToningShadowHue, m.splitToningShadowSaturation,
          grading, target);
      _splitZone(r, 'highlights', m.splitToningHighlightHue,
          m.splitToningHighlightSaturation, grading, target);
      if (m.splitToningBalance != null && m.splitToningBalance != 0) {
        r.unsupported('xmp.splitToningBalance',
            'split-toning balance differs from NP3 grading balance');
      }
    }

    // Shadow tint -> shadow zone tint (approx).
    if (m.shadowTint != null && m.shadowTint != 0) {
      final tint = m.shadowTint!;
      final zone =
          grading['shadows'] ?? const GradingZone();
      final hue = tint > 0 ? 120 : 300;
      final chroma = _clamp((tint.abs() / 2).round(), target);
      grading['shadows'] = GradingZone(
          hue: hue, chroma: chroma, brightness: zone.brightness);
      r.add('xmp.shadowTint', 'color.colorGrading.shadows', _f(tint),
          'hue $hue chroma $chroma', MappingStatus.approximated,
          note: 'green/magenta tint approximated as shadow-zone hue');
    }

    // ---- tone curve ---------------------------------------------------------
    ToneCurve? curve;
    final curveIsIdentity = CurveBuilder.isIdentityCurve(m.toneCurve);
    final hasParametric = (m.parametricShadows ?? 0) != 0 ||
        (m.parametricDarks ?? 0) != 0 ||
        (m.parametricLights ?? 0) != 0 ||
        (m.parametricHighlights ?? 0) != 0;

    if (!curveIsIdentity) {
      final pts = CurveBuilder.parseCurveString(m.toneCurve!);
      curve = CurveBuilder.fromControlPoints(pts);
      r.add('xmp.toneCurve', 'tone.toneCurve', '${pts.length} pts',
          '256-entry LUT', MappingStatus.approximated,
          note: 'point curve interpolated to NP3 LUT');
      _supersedeTonalSliders(r, [
        if (contrast != null) 'xmp.contrast',
        if (highlights != null) 'xmp.highlights',
        if (shadows != null) 'xmp.shadows',
        if (whiteLevel != null) 'xmp.whites',
        if (blackLevel != null) 'xmp.blacks',
      ]);
      contrast = null;
      highlights = null;
      shadows = null;
      whiteLevel = null;
      blackLevel = null;
    } else if (hasParametric) {
      final s = (m.parametricShadows ?? 0) * 128;
      final h = (m.parametricHighlights ?? 0) * 128;
      curve = CurveBuilder.fromHighlightShadow(h, s);
      r.add('xmp.parametric', 'tone.toneCurve',
          'sh ${m.parametricShadows} hi ${m.parametricHighlights}', '256-entry LUT',
          MappingStatus.approximated,
          note: 'parametric sliders approximated as highlight/shadow curve');
      _supersedeTonalSliders(r, [
        if (contrast != null) 'xmp.contrast',
        if (highlights != null) 'xmp.highlights',
        if (shadows != null) 'xmp.shadows',
        if (whiteLevel != null) 'xmp.whites',
        if (blackLevel != null) 'xmp.blacks',
      ]);
      contrast = null;
      highlights = null;
      shadows = null;
      whiteLevel = null;
      blackLevel = null;
    }

    // ---- unsupported / metadata -------------------------------------------
    _maybeUnsupported(r, 'xmp.exposure', m.exposure,
        'exposure is a camera setting, not a Picture Control parameter');
    _maybeUnsupported(r, 'xmp.whiteBalance', m.whiteBalance == null ? null : 1,
        'white balance is a camera setting; not stored in NP3');
    _rgb(r, 'xmp.toneCurveRed', m.toneCurveRed, 'per-channel curve: red');
    _rgb(r, 'xmp.toneCurveGreen', m.toneCurveGreen, 'per-channel curve: green');
    _rgb(r, 'xmp.toneCurveBlue', m.toneCurveBlue, 'per-channel curve: blue');
    _maybeUnsupported(r, 'xmp.grainAmount', m.grainAmount, 'grain has no NP3 equivalent');
    _maybeUnsupported(r, 'xmp.grainSize', m.grainSize, 'grain size has no NP3 equivalent');
    _maybeUnsupported(r, 'xmp.grainRoughness', m.grainRoughness,
        'grain roughness has no NP3 equivalent');
    _maybeUnsupported(r, 'xmp.vignetteAmount', m.vignetteAmount,
        'vignette has no NP3 equivalent');

    final nikon = NikonParams(
      name: name,
      contrast: contrast,
      highlights: highlights,
      shadows: shadows,
      whiteLevel: whiteLevel,
      blackLevel: blackLevel,
      saturation: saturation,
      sharpening: sharpening,
      colorBlender: blender.isEmpty ? null : blender,
      colorGrading: grading.isEmpty ? null : grading,
      gradingBlending: blending,
      gradingBalance: balance,
      clarity: clarity,
      toneCurve: curve,
    );

    final report = MappingReport(
      sourceFormat: 'xmp',
      target: target.name,
      fields: r.fields,
      mappingVersion: version,
    );
    return (nikon, report);
  }

  static int _clamp(int v, TargetProfile t) => v.clamp(t.toneMin, t.toneMax);

  static int? _tone1to1(
      String src, String nikonField, double? v, _Report r, TargetProfile target) {
    if (v == null || v == 0) return null;
    final out = _clamp(v.round(), target);
    r.add(src, 'tone.$nikonField', _f(v), _f(out),
        out == v.round() ? MappingStatus.exact : MappingStatus.clamped);
    return out;
  }

  static void _splitZone(_Report r, String zone, double? hue, double? sat,
      Map<String, GradingZone> grading, TargetProfile target) {
    if ((hue == null || hue == 0) && (sat == null || sat == 0)) return;
    final chroma = sat == null ? 0 : _clamp(sat.round(), target);
    final h = hue == null ? 0 : hue.round().clamp(0, 360);
    grading[zone] = GradingZone(hue: h, chroma: chroma, brightness: 0);
    r.add('xmp.splitToning$zone', 'color.colorGrading.$zone',
        'hue $hue sat $sat', 'hue $h chroma $chroma', MappingStatus.approximated,
        note: 'legacy split toning approximated as color-grading zone');
  }

  static void _supersedeTonalSliders(_Report r, List<String> srcs) {
    for (final s in srcs) {
      r.supersede(s,
          'overridden by custom tone curve (NP3 sentinel); set on camera if needed');
    }
  }

  static void _maybeUnsupported(_Report r, String src, double? v, String note) {
    if (v == null || v == 0) return;
    r.unsupported(src, note);
  }

  static void _rgb(_Report r, String src, String? v, String note) {
    final t = v?.trim() ?? '';
    if (t.isEmpty || t == '0 0, 255 255' || t == '255 255, 0 0') return;
    r.unsupported(src, note);
  }

  static String _f(num? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2));
}

/// Small accumulator that keeps report-building readable.
class _Report {
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

  void unsupported(String src, String? note) {
    fields.add(FieldMapping(
        sourceField: src,
        targetField: '',
        sourceValue: '',
        targetValue: null,
        status: MappingStatus.unsupported,
        note: note));
  }

  void supersede(String src, String? note) {
    fields.add(FieldMapping(
        sourceField: src,
        targetField: '',
        sourceValue: '',
        targetValue: null,
        status: MappingStatus.superseded,
        note: note));
  }

}