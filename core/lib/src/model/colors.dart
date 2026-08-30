/// One of the 8 hue channels in a Nikon color blender.
class ColorChannel {
  const ColorChannel({this.hue = 0, this.chroma = 0, this.brightness = 0});

  /// -100..100
  final int hue;

  /// -100..100
  final int chroma;

  /// -100..100
  final int brightness;

  static const List<String> channelNames = [
    'red',
    'orange',
    'yellow',
    'green',
    'cyan',
    'blue',
    'purple',
    'magenta',
  ];

  bool get isNeutral => hue == 0 && chroma == 0 && brightness == 0;

  ColorChannel copyWith({int? hue, int? chroma, int? brightness}) => ColorChannel(
        hue: hue ?? this.hue,
        chroma: chroma ?? this.chroma,
        brightness: brightness ?? this.brightness,
      );

  Map<String, Object?> toJson() => {'hue': hue, 'chroma': chroma, 'brightness': brightness};

  factory ColorChannel.fromJson(Map<String, Object?> j) => ColorChannel(
        hue: (j['hue'] as num?)?.toInt() ?? 0,
        chroma: (j['chroma'] as num?)?.toInt() ?? 0,
        brightness: (j['brightness'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is ColorChannel &&
      other.hue == hue &&
      other.chroma == chroma &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(hue, chroma, brightness);

  @override
  String toString() => 'ColorChannel($hue, $chroma, $brightness)';
}

/// Per-zone color grading (highlights / midtones / shadows).
class GradingZone {
  const GradingZone({this.hue = 0, this.chroma = 0, this.brightness = 0});

  /// 0..360
  final int hue;

  /// -100..100
  final int chroma;

  /// -100..100
  final int brightness;

  static const List<String> zoneNames = ['highlights', 'midtones', 'shadows'];

  bool get isNeutral => hue == 0 && chroma == 0 && brightness == 0;

  Map<String, Object?> toJson() => {'hue': hue, 'chroma': chroma, 'brightness': brightness};

  factory GradingZone.fromJson(Map<String, Object?> j) => GradingZone(
        hue: (j['hue'] as num?)?.toInt() ?? 0,
        chroma: (j['chroma'] as num?)?.toInt() ?? 0,
        brightness: (j['brightness'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is GradingZone &&
      other.hue == hue &&
      other.chroma == chroma &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(hue, chroma, brightness);

  @override
  String toString() => 'GradingZone($hue, $chroma, $brightness)';
}

/// A Nikon tone curve: a 256-entry 16-bit LUT plus its control points.
///
/// The NP3 chunk stores 256 x uint16 BE where `lut[i]` is the 0..32767 output
/// for 8-bit input `i + 1` (input 0 is implicitly 0). The control-point table
/// is what a curve editor displays; the LUT is what the camera applies.
class ToneCurve {
  const ToneCurve({required this.lut, required this.points});

  /// 256 entries, each 0..32767, monotonic non-decreasing.
  final List<int> lut;

  /// Control points as (x, y) pairs, 0..255 each. The last two are the fixed
  /// white (255,255) and black (0,0) anchors.
  final List<Point> points;

  /// Identity curve: output == input.
  ///
  /// Uses the camera's own rounding (half-up): the LUT Nikon writes for a
  /// neutral curve is `round((i + 1) * 32767 / 256)`, verified against the
  /// `tonecurve-noop.NP3` sample.
  static ToneCurve identity() => ToneCurve(
        lut: List<int>.generate(256, (i) {
          final v = ((i + 1) * 32767) / 256.0;
          return v.clamp(0, 32767).round();
        }),
        points: const [Point(0, 0), Point(255, 255)],
      );

  bool get isIdentity {
    final id = identity().lut;
    for (var i = 0; i < 256; i++) {
      if (lut[i] != id[i]) return false;
    }
    return true;
  }

  Map<String, Object?> toJson() => {
        'lut': lut,
        'points': points.map((p) => [p.x, p.y]).toList(),
      };

  factory ToneCurve.fromJson(Map<String, Object?> j) => ToneCurve(
        lut: (j['lut'] as List).map((e) => (e as num).toInt()).toList(),
        points: (j['points'] as List)
            .map((e) => Point((e[0] as num).toInt(), (e[1] as num).toInt()))
            .toList(),
      );
}

/// A 2D control point on a tone curve.
class Point {
  const Point(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}