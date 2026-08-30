/// White balance information kept from the source (NP3 does not carry WB;
/// it is a camera exposure setting, so this is metadata only).
class WbInfo {
  const WbInfo({this.mode, this.temperature, this.tint});

  /// e.g. "Daylight", "Tungsten", "Fluorescent", "Cloudy", "Shade",
  /// "Incandescent", "Manual", "Auto", or a Fuji/Adobe mode string.
  final String? mode;

  /// Kelvin, when the source exposes it (Lightroom manual WB, 2000..50000).
  final double? temperature;

  /// -150..+150 (Lightroom tint scale).
  final double? tint;

  bool get isNeutral => mode == null && temperature == null && (tint == null || tint == 0);

  Map<String, Object?> toJson() => {
        if (mode != null) 'mode': mode,
        if (temperature != null) 'temperature': temperature,
        if (tint != null) 'tint': tint,
      };

  factory WbInfo.fromJson(Map<String, Object?> j) => WbInfo(
        mode: j['mode'] as String?,
        temperature: (j['temperature'] as num?)?.toDouble(),
        tint: (j['tint'] as num?)?.toDouble(),
      );
}

/// One of the 8 Lightroom HSL channels.
enum XmpHslColor { red, orange, yellow, green, aqua, blue, purple, magenta }

class HslAdjustment {
  const HslAdjustment({this.hue, this.saturation, this.luminance});

  /// -180..+180
  final double? hue;

  /// -100..+100
  final double? saturation;

  /// -100..+100
  final double? luminance;

  bool get isNeutral => hue == null && saturation == null && luminance == null;

  Map<String, Object?> toJson() => {
        if (hue != null) 'hue': hue,
        if (saturation != null) 'saturation': saturation,
        if (luminance != null) 'luminance': luminance,
      };

  factory HslAdjustment.fromJson(Map<String, Object?> j) => HslAdjustment(
        hue: (j['hue'] as num?)?.toDouble(),
        saturation: (j['saturation'] as num?)?.toDouble(),
        luminance: (j['luminance'] as num?)?.toDouble(),
      );
}

/// A zone in Lightroom's (new) Color Grade wheel.
class XmpColorGradeZone {
  const XmpColorGradeZone({this.hue, this.saturation, this.luminance});

  /// 0..360
  final double? hue;

  /// 0..100
  final double? saturation;

  /// -100..+100
  final double? luminance;

  bool get isNeutral => hue == null && saturation == null && luminance == null;

  Map<String, Object?> toJson() => {
        if (hue != null) 'hue': hue,
        if (saturation != null) 'saturation': saturation,
        if (luminance != null) 'luminance': luminance,
      };

  factory XmpColorGradeZone.fromJson(Map<String, Object?> j) => XmpColorGradeZone(
        hue: (j['hue'] as num?)?.toDouble(),
        saturation: (j['saturation'] as num?)?.toDouble(),
        luminance: (j['luminance'] as num?)?.toDouble(),
      );
}

/// Full parsed Lightroom XMP preset.
///
/// Kept verbatim on a [UniversalRecipe] so that (a) an XMP import can be
/// re-exported as XMP losslessly and (b) the fidelity report can show exactly
/// which source values were left behind on the Nikon target.
class XmpMeta {
  const XmpMeta({
    this.name,
    this.description,
    this.processVersion,
    this.whiteBalance,
    this.exposure,
    this.contrast,
    this.highlights,
    this.shadows,
    this.whites,
    this.blacks,
    this.vibrance,
    this.saturation,
    this.clarity,
    this.texture,
    this.dehaze,
    this.shadowTint,
    this.toneCurve,
    this.toneCurveRed,
    this.toneCurveGreen,
    this.toneCurveBlue,
    this.parametricShadows,
    this.parametricDarks,
    this.parametricLights,
    this.parametricHighlights,
    this.hsl,
    this.colorGradeHigh,
    this.colorGradeMid,
    this.colorGradeShadow,
    this.colorGradeBalance,
    this.colorGradeBlending,
    this.colorGradeGlobalSaturation,
    this.splitToningShadowHue,
    this.splitToningShadowSaturation,
    this.splitToningHighlightHue,
    this.splitToningHighlightSaturation,
    this.splitToningBalance,
    this.sharpening,
    this.sharpenDetail,
    this.sharpenRadius,
    this.sharpenEdgeMasking,
    this.grainAmount,
    this.grainSize,
    this.grainRoughness,
    this.vignetteAmount,
    this.vignetteMidpoint,
    this.vignetteRoundness,
    this.vignetteFeather,
    this.copyright,
    this.author,
  });

  final String? name;
  final String? description;

  /// 1 or 2 (ProcessVersion). Affects which scale the basic params use.
  final int? processVersion;

  final WbInfo? whiteBalance;

  /// EV, -5..+5 (pv2) / -2..+2 (pv1). Not a Picture Control parameter.
  final double? exposure;

  /// pv2: -150..+150; pv1: -50..+50.
  final double? contrast;

  /// -100..+100
  final double? highlights;

  /// 0..+100 (lift only, both pv).
  final double? shadows;

  /// -100..+100
  final double? whites;

  /// -100..0 (darken only, both pv).
  final double? blacks;

  /// -100..+100
  final double? vibrance;

  /// -100..+100
  final double? saturation;

  /// -100..+100
  final double? clarity;

  /// -100..+100. No NP3 equivalent.
  final double? texture;

  /// 0..+100. No NP3 equivalent.
  final double? dehaze;

  /// -100..+100 (shadow color tint).
  final double? shadowTint;

  /// "x,y x,y ..." point curve strings (0..255).
  final String? toneCurve;
  final String? toneCurveRed;
  final String? toneCurveGreen;
  final String? toneCurveBlue;

  /// Parametric tone curve sliders, each -100..+100 (or split 0..100).
  final double? parametricShadows;
  final double? parametricDarks;
  final double? parametricLights;
  final double? parametricHighlights;

  /// 8 channels of HSL.
  final Map<XmpHslColor, HslAdjustment>? hsl;

  final XmpColorGradeZone? colorGradeHigh;
  final XmpColorGradeZone? colorGradeMid;
  final XmpColorGradeZone? colorGradeShadow;
  final double? colorGradeBalance;
  final double? colorGradeBlending;
  final double? colorGradeGlobalSaturation;

  /// Legacy split toning.
  final double? splitToningShadowHue;
  final double? splitToningShadowSaturation;
  final double? splitToningHighlightHue;
  final double? splitToningHighlightSaturation;
  final double? splitToningBalance;

  /// Detail.
  /// Legacy sharpening, -300..+300.
  final double? sharpening;

  /// 0..100.
  final double? sharpenDetail;

  /// 0.1..2.5
  final double? sharpenRadius;

  /// 0..100
  final double? sharpenEdgeMasking;

  /// 0..100 each. No NP3 equivalent.
  final double? grainAmount;
  final double? grainSize;
  final double? grainRoughness;

  /// Vignette. No NP3 equivalent.
  final double? vignetteAmount;
  final double? vignetteMidpoint;
  final double? vignetteRoundness;
  final double? vignetteFeather;

  final String? copyright;
  final String? author;

  /// True when the preset is effectively a no-op (all fields neutral).
  bool get isNeutral {
    return contrast == null &&
        highlights == null &&
        shadows == null &&
        whites == null &&
        blacks == null &&
        saturation == null &&
        vibrance == null &&
        clarity == null &&
        (hsl == null || hsl!.values.every((h) => h.isNeutral)) &&
        (toneCurve == null || toneCurve == '0,0 255,255' || toneCurve!.trim().isEmpty) &&
        grainAmount == null &&
        vignetteAmount == null;
  }

  Map<String, Object?> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (processVersion != null) 'processVersion': processVersion,
        if (whiteBalance != null) 'whiteBalance': whiteBalance!.toJson(),
        if (exposure != null) 'exposure': exposure,
        if (contrast != null) 'contrast': contrast,
        if (highlights != null) 'highlights': highlights,
        if (shadows != null) 'shadows': shadows,
        if (whites != null) 'whites': whites,
        if (blacks != null) 'blacks': blacks,
        if (vibrance != null) 'vibrance': vibrance,
        if (saturation != null) 'saturation': saturation,
        if (clarity != null) 'clarity': clarity,
        if (texture != null) 'texture': texture,
        if (dehaze != null) 'dehaze': dehaze,
        if (shadowTint != null) 'shadowTint': shadowTint,
        if (toneCurve != null) 'toneCurve': toneCurve,
        if (toneCurveRed != null) 'toneCurveRed': toneCurveRed,
        if (toneCurveGreen != null) 'toneCurveGreen': toneCurveGreen,
        if (toneCurveBlue != null) 'toneCurveBlue': toneCurveBlue,
        if (parametricShadows != null) 'parametricShadows': parametricShadows,
        if (parametricDarks != null) 'parametricDarks': parametricDarks,
        if (parametricLights != null) 'parametricLights': parametricLights,
        if (parametricHighlights != null) 'parametricHighlights': parametricHighlights,
        if (hsl != null)
          'hsl': hsl!.map((k, v) => MapEntry(k.name, v.toJson())),
        if (colorGradeHigh != null) 'colorGradeHigh': colorGradeHigh!.toJson(),
        if (colorGradeMid != null) 'colorGradeMid': colorGradeMid!.toJson(),
        if (colorGradeShadow != null) 'colorGradeShadow': colorGradeShadow!.toJson(),
        if (colorGradeBalance != null) 'colorGradeBalance': colorGradeBalance,
        if (colorGradeBlending != null) 'colorGradeBlending': colorGradeBlending,
        if (colorGradeGlobalSaturation != null) 'colorGradeGlobalSaturation': colorGradeGlobalSaturation,
        if (splitToningShadowHue != null) 'splitToningShadowHue': splitToningShadowHue,
        if (splitToningShadowSaturation != null) 'splitToningShadowSaturation': splitToningShadowSaturation,
        if (splitToningHighlightHue != null) 'splitToningHighlightHue': splitToningHighlightHue,
        if (splitToningHighlightSaturation != null) 'splitToningHighlightSaturation': splitToningHighlightSaturation,
        if (splitToningBalance != null) 'splitToningBalance': splitToningBalance,
        if (sharpening != null) 'sharpening': sharpening,
        if (sharpenDetail != null) 'sharpenDetail': sharpenDetail,
        if (sharpenRadius != null) 'sharpenRadius': sharpenRadius,
        if (sharpenEdgeMasking != null) 'sharpenEdgeMasking': sharpenEdgeMasking,
        if (grainAmount != null) 'grainAmount': grainAmount,
        if (grainSize != null) 'grainSize': grainSize,
        if (grainRoughness != null) 'grainRoughness': grainRoughness,
        if (vignetteAmount != null) 'vignetteAmount': vignetteAmount,
        if (vignetteMidpoint != null) 'vignetteMidpoint': vignetteMidpoint,
        if (vignetteRoundness != null) 'vignetteRoundness': vignetteRoundness,
        if (vignetteFeather != null) 'vignetteFeather': vignetteFeather,
        if (copyright != null) 'copyright': copyright,
        if (author != null) 'author': author,
      };

  factory XmpMeta.fromJson(Map<String, Object?> j) => XmpMeta(
        name: j['name'] as String?,
        description: j['description'] as String?,
        processVersion: (j['processVersion'] as num?)?.toInt(),
        whiteBalance: j['whiteBalance'] == null ? null : WbInfo.fromJson((j['whiteBalance'] as Map).cast<String, Object?>()),
        exposure: (j['exposure'] as num?)?.toDouble(),
        contrast: (j['contrast'] as num?)?.toDouble(),
        highlights: (j['highlights'] as num?)?.toDouble(),
        shadows: (j['shadows'] as num?)?.toDouble(),
        whites: (j['whites'] as num?)?.toDouble(),
        blacks: (j['blacks'] as num?)?.toDouble(),
        vibrance: (j['vibrance'] as num?)?.toDouble(),
        saturation: (j['saturation'] as num?)?.toDouble(),
        clarity: (j['clarity'] as num?)?.toDouble(),
        texture: (j['texture'] as num?)?.toDouble(),
        dehaze: (j['dehaze'] as num?)?.toDouble(),
        shadowTint: (j['shadowTint'] as num?)?.toDouble(),
        toneCurve: j['toneCurve'] as String?,
        toneCurveRed: j['toneCurveRed'] as String?,
        toneCurveGreen: j['toneCurveGreen'] as String?,
        toneCurveBlue: j['toneCurveBlue'] as String?,
        parametricShadows: (j['parametricShadows'] as num?)?.toDouble(),
        parametricDarks: (j['parametricDarks'] as num?)?.toDouble(),
        parametricLights: (j['parametricLights'] as num?)?.toDouble(),
        parametricHighlights: (j['parametricHighlights'] as num?)?.toDouble(),
        hsl: (j['hsl'] as Map?)?.map(
              (k, v) => MapEntry(
                    XmpHslColor.values.byName(k as String? ?? 'red'),
                    HslAdjustment.fromJson((v as Map).cast<String, Object?>()),
                  ),
            ),
        colorGradeHigh: j['colorGradeHigh'] == null ? null : XmpColorGradeZone.fromJson((j['colorGradeHigh'] as Map).cast<String, Object?>()),
        colorGradeMid: j['colorGradeMid'] == null ? null : XmpColorGradeZone.fromJson((j['colorGradeMid'] as Map).cast<String, Object?>()),
        colorGradeShadow: j['colorGradeShadow'] == null ? null : XmpColorGradeZone.fromJson((j['colorGradeShadow'] as Map).cast<String, Object?>()),
        colorGradeBalance: (j['colorGradeBalance'] as num?)?.toDouble(),
        colorGradeBlending: (j['colorGradeBlending'] as num?)?.toDouble(),
        colorGradeGlobalSaturation: (j['colorGradeGlobalSaturation'] as num?)?.toDouble(),
        splitToningShadowHue: (j['splitToningShadowHue'] as num?)?.toDouble(),
        splitToningShadowSaturation: (j['splitToningShadowSaturation'] as num?)?.toDouble(),
        splitToningHighlightHue: (j['splitToningHighlightHue'] as num?)?.toDouble(),
        splitToningHighlightSaturation: (j['splitToningHighlightSaturation'] as num?)?.toDouble(),
        splitToningBalance: (j['splitToningBalance'] as num?)?.toDouble(),
        sharpening: (j['sharpening'] as num?)?.toDouble(),
        sharpenDetail: (j['sharpenDetail'] as num?)?.toDouble(),
        sharpenRadius: (j['sharpenRadius'] as num?)?.toDouble(),
        sharpenEdgeMasking: (j['sharpenEdgeMasking'] as num?)?.toDouble(),
        grainAmount: (j['grainAmount'] as num?)?.toDouble(),
        grainSize: (j['grainSize'] as num?)?.toDouble(),
        grainRoughness: (j['grainRoughness'] as num?)?.toDouble(),
        vignetteAmount: (j['vignetteAmount'] as num?)?.toDouble(),
        vignetteMidpoint: (j['vignetteMidpoint'] as num?)?.toDouble(),
        vignetteRoundness: (j['vignetteRoundness'] as num?)?.toDouble(),
        vignetteFeather: (j['vignetteFeather'] as num?)?.toDouble(),
        copyright: j['copyright'] as String?,
        author: j['author'] as String?,
      );
}