import 'colors.dart';

/// Where a recipe originally came from.
enum SourceFormat {
  np3,
  xmp,
  fujiText,
  nikonCloud,
  builtin,
  user,
  unknown;

  String get label => switch (this) {
        SourceFormat.np3 => 'Nikon NP3',
        SourceFormat.xmp => 'Lightroom XMP',
        SourceFormat.fujiText => 'Fuji recipe',
        SourceFormat.nikonCloud => 'Nikon Imaging Cloud',
        SourceFormat.builtin => 'Phos catalog',
        SourceFormat.user => 'User-created',
        SourceFormat.unknown => 'Unknown',
      };
}

/// Exactly the parameters a Nikon Picture Control (.NP3/.NCP) can hold.
///
/// This is the "Nikon projection" of a [UniversalRecipe]. All tone values are
/// on the Nikon -100..+100 scale; detail values are on their native Nikon
/// scales. Null means "at the neutral default".
class NikonParams {
  const NikonParams({
    this.name,
    this.comment,
    this.contrast,
    this.highlights,
    this.shadows,
    this.whiteLevel,
    this.blackLevel,
    this.saturation,
    this.sharpening,
    this.midRangeSharpening,
    this.clarity,
    this.colorBlender,
    this.colorGrading,
    this.gradingBlending,
    this.gradingBalance,
    this.toneCurve,
    this.baseProfileHint,
  });

  static const int toneMin = -100;
  static const int toneMax = 100;

  final String? name;
  final String? comment;

  /// Quick-adjust tonal sliders, -100..+100.
  final int? contrast;
  final int? highlights;
  final int? shadows;
  final int? whiteLevel;
  final int? blackLevel;

  /// -100..+100
  final int? saturation;

  /// -3..+9, step 0.25
  final double? sharpening;

  /// -5..+5, step 0.25
  final double? midRangeSharpening;

  /// -5..+5, step 0.25
  final double? clarity;

  /// 8 hue channels: red, orange, yellow, green, cyan, blue, purple, magenta.
  final Map<String, ColorChannel>? colorBlender;

  /// 3 zones: highlights, midtones, shadows.
  final Map<String, GradingZone>? colorGrading;

  /// 0..100 (default 50)
  final int? gradingBlending;

  /// -100..+100
  final int? gradingBalance;

  /// Custom tone curve. When present and non-identity, the tonal sliders
  /// above are overridden on the camera (NP3 sentinel).
  final ToneCurve? toneCurve;

  /// Informational: which base Picture Control pairs well with this look
  /// (e.g. a Fuji Classic Chrome conversion suggests "Standard").
  final String? baseProfileHint;

  bool get hasToneCurve => toneCurve != null && !toneCurve!.isIdentity;

  /// The flexible-color base defaults that a parsed file always reports for
  /// the quarter-step detail values (they are never stored as null).
  static const double defaultSharpening = 2.0;
  static const double defaultClarity = 0.5;
  static const double defaultMidRangeSharpening = 1.0;

  bool get isNeutral {
    if (hasToneCurve) return false;
    // Parsed files always report concrete slider values (0 = neutral), so
    // treat null and 0 the same way.
    if (contrast != null && contrast != 0) return false;
    if (highlights != null && highlights != 0) return false;
    if (shadows != null && shadows != 0) return false;
    if (whiteLevel != null && whiteLevel != 0) return false;
    if (blackLevel != null && blackLevel != 0) return false;
    if (saturation != null && saturation != 0) return false;
    if (sharpening != null && sharpening != defaultSharpening) return false;
    if (clarity != null && clarity != defaultClarity) return false;
    if (midRangeSharpening != null &&
        midRangeSharpening != defaultMidRangeSharpening) {
      return false;
    }
    if (colorBlender != null && colorBlender!.values.any((c) => !c.isNeutral)) return false;
    if (colorGrading != null && colorGrading!.values.any((z) => !z.isNeutral)) return false;
    if (gradingBlending != null && gradingBlending != 50) return false;
    if (gradingBalance != null && gradingBalance != 0) return false;
    return true;
  }

  NikonParams copyWith({
    String? name,
    String? comment,
    int? contrast,
    int? highlights,
    int? shadows,
    int? whiteLevel,
    int? blackLevel,
    int? saturation,
    double? sharpening,
    double? midRangeSharpening,
    double? clarity,
    Map<String, ColorChannel>? colorBlender,
    Map<String, GradingZone>? colorGrading,
    int? gradingBlending,
    int? gradingBalance,
    ToneCurve? toneCurve,
    String? baseProfileHint,
  }) {
    return NikonParams(
      name: name ?? this.name,
      comment: comment ?? this.comment,
      contrast: contrast ?? this.contrast,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      whiteLevel: whiteLevel ?? this.whiteLevel,
      blackLevel: blackLevel ?? this.blackLevel,
      saturation: saturation ?? this.saturation,
      sharpening: sharpening ?? this.sharpening,
      midRangeSharpening: midRangeSharpening ?? this.midRangeSharpening,
      clarity: clarity ?? this.clarity,
      colorBlender: colorBlender ?? this.colorBlender,
      colorGrading: colorGrading ?? this.colorGrading,
      gradingBlending: gradingBlending ?? this.gradingBlending,
      gradingBalance: gradingBalance ?? this.gradingBalance,
      toneCurve: toneCurve ?? this.toneCurve,
      baseProfileHint: baseProfileHint ?? this.baseProfileHint,
    );
  }

  Map<String, Object?> toJson() => {
        if (name != null) 'name': name,
        if (comment != null) 'comment': comment,
        if (contrast != null) 'contrast': contrast,
        if (highlights != null) 'highlights': highlights,
        if (shadows != null) 'shadows': shadows,
        if (whiteLevel != null) 'whiteLevel': whiteLevel,
        if (blackLevel != null) 'blackLevel': blackLevel,
        if (saturation != null) 'saturation': saturation,
        if (sharpening != null) 'sharpening': sharpening,
        if (midRangeSharpening != null) 'midRangeSharpening': midRangeSharpening,
        if (clarity != null) 'clarity': clarity,
        if (colorBlender != null)
          'colorBlender':
              colorBlender!.map((k, v) => MapEntry(k, v.toJson())),
        if (colorGrading != null)
          'colorGrading': colorGrading!.map((k, v) => MapEntry(k, v.toJson())),
        if (gradingBlending != null) 'gradingBlending': gradingBlending,
        if (gradingBalance != null) 'gradingBalance': gradingBalance,
        if (toneCurve != null) 'toneCurve': toneCurve!.toJson(),
        if (baseProfileHint != null) 'baseProfileHint': baseProfileHint,
      };

  factory NikonParams.fromJson(Map<String, Object?> j) => NikonParams(
        name: j['name'] as String?,
        comment: j['comment'] as String?,
        contrast: (j['contrast'] as num?)?.toInt(),
        highlights: (j['highlights'] as num?)?.toInt(),
        shadows: (j['shadows'] as num?)?.toInt(),
        whiteLevel: (j['whiteLevel'] as num?)?.toInt(),
        blackLevel: (j['blackLevel'] as num?)?.toInt(),
        saturation: (j['saturation'] as num?)?.toInt(),
        sharpening: (j['sharpening'] as num?)?.toDouble(),
        midRangeSharpening: (j['midRangeSharpening'] as num?)?.toDouble(),
        clarity: (j['clarity'] as num?)?.toDouble(),
        colorBlender: (j['colorBlender'] as Map?)?.map(
              (k, v) =>
                  MapEntry(k as String, ColorChannel.fromJson((v as Map).cast<String, Object?>())),
            ),
        colorGrading: (j['colorGrading'] as Map?)?.map(
              (k, v) =>
                  MapEntry(k as String, GradingZone.fromJson((v as Map).cast<String, Object?>())),
            ),
        gradingBlending: (j['gradingBlending'] as num?)?.toInt(),
        gradingBalance: (j['gradingBalance'] as num?)?.toInt(),
        toneCurve: j['toneCurve'] == null
            ? null
            : ToneCurve.fromJson((j['toneCurve'] as Map).cast<String, Object?>()),
        baseProfileHint: j['baseProfileHint'] as String?,
      );
}