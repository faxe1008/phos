/// Parsed Fujifilm film-simulation "recipe" (fujixweekly-style text block).
///
/// Kept verbatim on a [UniversalRecipe] so the fidelity report can show which
/// Fuji values have no Nikon equivalent (grain, ISO, exposure comp, ...).
class FujiMeta {
  const FujiMeta({
    this.filmSimulation,
    this.dynamicRange,
    this.highlightTone,
    this.shadowTone,
    this.color,
    this.noiseReduction,
    this.sharpness,
    this.clarity,
    this.grainStrength,
    this.grainSize,
    this.colorChromeEffect,
    this.colorChromeEffectBlue,
    this.whiteBalanceMode,
    this.wbRedShift,
    this.wbBlueShift,
    this.iso,
    this.exposureComp,
  });

  /// e.g. "Classic Chrome", "Velvia", "Pro Neg Hi", "Astia".
  final String? filmSimulation;

  /// "DR100" | "DR200" | "DR400" | "AUTO" | ...
  final String? dynamicRange;

  /// -2..+4
  final double? highlightTone;

  /// -2..+4
  final double? shadowTone;

  /// -4..+4
  final double? color;

  /// -3..+3 (0..3 on newer bodies)
  final double? noiseReduction;

  /// -4..+4
  final double? sharpness;

  /// -5..+5
  final double? clarity;

  /// "Off" | "Weak" | "Strong"
  final String? grainStrength;
  final String? grainSize;

  /// "Off" | "Weak" | "Strong"
  final String? colorChromeEffect;
  final String? colorChromeEffectBlue;

  final String? whiteBalanceMode;

  /// -9..+9
  final int? wbRedShift;

  /// -9..+9
  final int? wbBlueShift;

  final String? iso;
  final String? exposureComp;

  Map<String, Object?> toJson() => {
        if (filmSimulation != null) 'filmSimulation': filmSimulation,
        if (dynamicRange != null) 'dynamicRange': dynamicRange,
        if (highlightTone != null) 'highlightTone': highlightTone,
        if (shadowTone != null) 'shadowTone': shadowTone,
        if (color != null) 'color': color,
        if (noiseReduction != null) 'noiseReduction': noiseReduction,
        if (sharpness != null) 'sharpness': sharpness,
        if (clarity != null) 'clarity': clarity,
        if (grainStrength != null) 'grainStrength': grainStrength,
        if (grainSize != null) 'grainSize': grainSize,
        if (colorChromeEffect != null) 'colorChromeEffect': colorChromeEffect,
        if (colorChromeEffectBlue != null) 'colorChromeEffectBlue': colorChromeEffectBlue,
        if (whiteBalanceMode != null) 'whiteBalanceMode': whiteBalanceMode,
        if (wbRedShift != null) 'wbRedShift': wbRedShift,
        if (wbBlueShift != null) 'wbBlueShift': wbBlueShift,
        if (iso != null) 'iso': iso,
        if (exposureComp != null) 'exposureComp': exposureComp,
      };

  factory FujiMeta.fromJson(Map<String, Object?> j) => FujiMeta(
        filmSimulation: j['filmSimulation'] as String?,
        dynamicRange: j['dynamicRange'] as String?,
        highlightTone: (j['highlightTone'] as num?)?.toDouble(),
        shadowTone: (j['shadowTone'] as num?)?.toDouble(),
        color: (j['color'] as num?)?.toDouble(),
        noiseReduction: (j['noiseReduction'] as num?)?.toDouble(),
        sharpness: (j['sharpness'] as num?)?.toDouble(),
        clarity: (j['clarity'] as num?)?.toDouble(),
        grainStrength: j['grainStrength'] as String?,
        grainSize: j['grainSize'] as String?,
        colorChromeEffect: j['colorChromeEffect'] as String?,
        colorChromeEffectBlue: j['colorChromeEffectBlue'] as String?,
        whiteBalanceMode: j['whiteBalanceMode'] as String?,
        wbRedShift: (j['wbRedShift'] as num?)?.toInt(),
        wbBlueShift: (j['wbBlueShift'] as num?)?.toInt(),
        iso: j['iso'] as String?,
        exposureComp: j['exposureComp'] as String?,
      );
}