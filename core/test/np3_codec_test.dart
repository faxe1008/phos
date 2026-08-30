import 'dart:math' as math;

import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

void main() {
  test('generate defaults: neutral flexible-color base', () {
    final p = Np3Codec.parse(Np3Codec.generate(const NikonParams()));
    expect(p.name, 'Recipe');
    expect(p.contrast, 0);
    expect(p.highlights, 0);
    expect(p.shadows, 0);
    expect(p.whiteLevel, 0);
    expect(p.blackLevel, 0);
    expect(p.saturation, 0);
    expect(p.sharpening, 2.0);
    expect(p.clarity, 0.5);
    expect(p.midRangeSharpening, 1.0);
    expect(p.gradingBlending, 50);
    expect(p.gradingBalance, 0);
    expect(p.toneCurve, isNull);
    expect(p.isNeutral, isTrue);
  });

  test('tonal and detail values round-trip', () {
    final p = NikonParams(
      name: 'Test',
      contrast: 33,
      highlights: -21,
      shadows: 17,
      whiteLevel: 8,
      blackLevel: -12,
      saturation: -45,
      sharpening: 4.5,
      clarity: -1.25,
      midRangeSharpening: 2.0,
    );
    final q = Np3Codec.parse(Np3Codec.generate(p));
    expect(q.name, 'Test');
    expect(q.contrast, 33);
    expect(q.highlights, -21);
    expect(q.shadows, 17);
    expect(q.whiteLevel, 8);
    expect(q.blackLevel, -12);
    expect(q.saturation, -45);
    expect(q.sharpening, 4.5);
    expect(q.clarity, -1.25);
    expect(q.midRangeSharpening, 2.0);
  });

  test('values beyond range are clamped', () {
    final q = Np3Codec.parse(
        Np3Codec.generate(const NikonParams(contrast: 250, saturation: -400)));
    expect(q.contrast, 100);
    expect(q.saturation, -100);
  });

  test('name is sanitized to 19 printable ASCII chars', () {
    final q = Np3Codec.parse(
        Np3Codec.generate(NikonParams(name: 'A very long name with emoji 📷!!')));
    expect(q.name, 'A very long name wi');
    expect(q.name!.length, lessThanOrEqualTo(19));
  });

  test('color blender channels round-trip', () {
    final p = NikonParams(
      name: 'Blender',
      colorBlender: {
        'red': const ColorChannel(hue: 12, chroma: -30, brightness: 5),
        'green': const ColorChannel(chroma: 40),
      },
    );
    final q = Np3Codec.parse(Np3Codec.generate(p));
    expect(q.colorBlender!['red'], const ColorChannel(hue: 12, chroma: -30, brightness: 5));
    expect(q.colorBlender!['green'], const ColorChannel(chroma: 40));
    expect(q.colorBlender!['blue'], const ColorChannel(),
        reason: 'unset channels must be neutral');
  });

  test('color grading zones, blending and balance round-trip', () {
    final p = NikonParams(
      name: 'Grade',
      colorGrading: {
        'highlights': const GradingZone(hue: 40, chroma: 20, brightness: -10),
        'midtones': const GradingZone(hue: 35, chroma: 15),
        'shadows': const GradingZone(hue: 200, chroma: 30, brightness: 5),
      },
      gradingBlending: 75,
      gradingBalance: -20,
    );
    final q = Np3Codec.parse(Np3Codec.generate(p));
    expect(q.colorGrading!['highlights'],
        const GradingZone(hue: 40, chroma: 20, brightness: -10));
    expect(q.colorGrading!['midtones'], const GradingZone(hue: 35, chroma: 15));
    expect(q.colorGrading!['shadows'], const GradingZone(hue: 200, chroma: 30, brightness: 5));
    expect(q.gradingBlending, 75);
    expect(q.gradingBalance, -20);
  });

  test('grading zone hue is a 12-bit value (up to 4095)', () {
    final p = NikonParams(
      name: 'Hue12',
      colorGrading: {
        'midtones': const GradingZone(hue: 4000, chroma: 10),
      },
    );
    final q = Np3Codec.parse(Np3Codec.generate(p));
    expect(q.colorGrading!['midtones']!.hue, 4000);
  });

  test('comment round-trips (incl. multi-byte UTF-8)', () {
    for (final c in ['hello', 'a', '日本語コメント', 'x' * 200]) {
      final q =
          Np3Codec.parse(Np3Codec.generate(NikonParams(name: 'C', comment: c)));
      expect(q.comment, c, reason: 'comment: $c');
    }
  });

  test('tone curve round-trips through the chunk', () {
    // A smooth S-curve LUT (monotonic, 0..32767).
    final lut = List<int>.generate(256, (i) {
      final x = (i + 1) / 256;
      final s = 1 / (1 + math.exp(-x * 8)) - 0.5; // -0.5..0.5
      final v = (x + s * 0.3) * 32767;
      return v.clamp(0, 32767).round();
    });
    // Enforce monotonicity.
    for (var i = 1; i < lut.length; i++) {
      if (lut[i] < lut[i - 1]) lut[i] = lut[i - 1];
    }
    final curve = ToneCurve(
      lut: lut,
      points: const [Point(64, 70), Point(160, 170), Point(255, 255), Point(0, 0)],
    );
    final p = NikonParams(
      name: 'Curve',
      contrast: 10, // will be nulled on output (sentinel)
      toneCurve: curve,
    );
    final q = Np3Codec.parse(Np3Codec.generate(p));
    expect(q.contrast, null, reason: 'sentinel must null the sliders');
    expect(q.toneCurve, isNotNull);
    expect(q.toneCurve!.lut, curve.lut);
    expect(q.toneCurve!.points.length, 4);
    expect(q.toneCurve!.points[0], const Point(64, 70));
    expect(q.toneCurve!.points[1], const Point(160, 170));
    expect(q.toneCurve!.points[2], const Point(255, 255));
    expect(q.toneCurve!.points[3], const Point(0, 0));
  });

  test('identity curve is not emitted as a chunk', () {
    final p = NikonParams(name: 'I', toneCurve: ToneCurve.identity());
    final q = Np3Codec.parse(Np3Codec.generate(p));
    expect(q.toneCurve, isNull,
        reason: 'identity curves must not trigger the sentinel');
  });

  test('chunk encoding rejects malformed curves', () {
    expect(
        () => Np3ToneCurveChunk.encode(ToneCurve(
            lut: List.filled(256, 0), points: const [Point(255, 255)])),
        throwsArgumentError,
        reason: 'needs at least the two anchors');
    expect(
        () => Np3ToneCurveChunk.encode(ToneCurve(
            lut: List.filled(256, 0),
            points: const [Point(10, 10), Point(0, 0), Point(255, 255)])),
        throwsArgumentError,
        reason: 'anchors must be last, white then black');
  });
}