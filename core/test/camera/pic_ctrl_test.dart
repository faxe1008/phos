import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

void main() {
  group('encode/decode', () {
    test('byte-exact 36-byte data set', () {
      final ds = PicCtrlDataSet(
        basePictureControl: 1,
        registrationName: 'Provia 100F',
        applyLevel: 100,
        sharpening: 8,
        middleRangeSharpening: 5,
        clarity: -12,
        contrast: -12,
        brightness: 4,
        saturation: -12,
        hue: 36,
      );
      final b = ds.encode();
      expect(b.length, 36);
      expect(b[0] | (b[1] << 8), 1); // base Standard
      // name: 11 ASCII chars + 9 NULs
      expect(
        String.fromCharCodes(b.sublist(2, 13)),
        'Provia 100F',
      );
      expect(b.sublist(13, 22), List.filled(9, 0));
      expect(b[22], 100); // apply level
      expect(b[23], 0); // quick sharp off
      expect(b[24], 0); // quick sharp
      expect(b[25], 8); // sharpening 8 x 0.25
      expect(b[26], 5); // mid range
      expect(b[27], 0xF4); // -12 two's complement
      expect(b[28], 0xF4);
      expect(b[29], 4); // +1
      expect(b[30], 0xF4);
      expect(b[31], 36); // hue +9
      expect(b[32], 0);
      expect(b[33], 0);
      expect(b[34], 0);
      expect(b[35], 0); // no curve
    });

    test('round-trips a curved 614-byte data set', () {
      final lut = PicCtrlDataSet.lutFromToneCurve(ToneCurve.identity());
      final ds = PicCtrlDataSet(
        basePictureControl: 2,
        registrationName: 'Neutral test',
        contrast: -12,
        customCurveFlag: true,
        lut: lut,
      );
      expect(ds.encode().length, 614);
      final back = PicCtrlDataSet.decode(ds.encode());
      expect(back.basePictureControl, 2);
      expect(back.registrationName, 'Neutral test');
      expect(back.contrast, -12);
      expect(back.customCurveFlag, isTrue);
      expect(back.lut, isNotNull);
      expect(back.lut!.length, 578);
      expect(back.readLut8()!.last, 255);
    });

    test('decode rejects wrong lengths', () {
      expect(
        () => PicCtrlDataSet.decode(List.filled(37, 0)),
        throwsFormatException,
      );
      expect(
        () => PicCtrlDataSet.decode(List.filled(100, 0)),
        throwsFormatException,
      );
    });

    test('encode rejects too-long or non-ASCII names', () {
      expect(
        () => PicCtrlDataSet(
          basePictureControl: 1,
          registrationName: 'x' * 20,
        ).encode(),
        throwsArgumentError,
      );
      expect(
        () => PicCtrlDataSet(
          basePictureControl: 1,
          registrationName: 'Über',
        ).encode(),
        throwsArgumentError,
      );
    });
  });

  group('fromNikon mapping', () {
    test('projects NP3 scales onto in-camera quarter steps', () {
      final ds = PicCtrlDataSet.fromNikon(
        const NikonParams(
          name: 'My Recipe!!',
          contrast: -100,
          blackLevel: -50,
          whiteLevel: -50,
          saturation: -100,
          sharpening: 2.0,
          midRangeSharpening: 1.0,
          clarity: -5.0,
          gradingBalance: 100,
          baseProfileHint: 'Neutral',
        ),
        baseCode: PicCtrlDataSet.baseCodeFor('Neutral'),
      );
      expect(ds.basePictureControl, 2); // Neutral
      expect(ds.registrationName, 'My Recipe!!');
      expect(ds.contrast, -12); // -100 -> -3.00
      expect(ds.brightness, -6); // (-50 + -50)/2 = -50 -> -1.50
      expect(ds.saturation, -12);
      expect(ds.sharpening, 8); // 2.00 -> 8 quarter steps
      expect(ds.middleRangeSharpening, 22); // (1+5)/10*36 = 21.6 -> 22
      expect(ds.clarity, -12); // -5 -> -3.00
      expect(ds.hue, 36); // +100 -> +9.00
      expect(ds.applyLevel, 100);
      expect(ds.quickSharpFlag, isFalse);
      expect(ds.customCurveFlag, isFalse);
      expect(ds.lut, isNull);
    });

    test('clamps out-of-range NP3 values', () {
      final ds = PicCtrlDataSet.fromNikon(
        const NikonParams(
          contrast: 1000, // far out of range
          sharpening: -3.0,
        ),
        baseCode: 1,
      );
      expect(ds.contrast, 12);
      expect(ds.sharpening, 0); // negative -> in-camera floor 0
    });

    test('attaches the LUT when the curve is non-identity', () {
      final curve = ToneCurve(
        lut: List<int>.generate(256, (i) => (i * i) ~/ 2),
        points: const [Point(0, 0), Point(128, 200), Point(255, 255)],
      );
      final ds = PicCtrlDataSet.fromNikon(
        NikonParams(name: 'Curve', toneCurve: curve),
        baseCode: 1,
      );
      expect(ds.customCurveFlag, isTrue);
      expect(ds.encode().length, 614);
    });

    test('baseCodeFor maps hints to spec 9.9.1 codes', () {
      expect(PicCtrlDataSet.baseCodeFor('Neutral'), 2);
      expect(PicCtrlDataSet.baseCodeFor('Vivid'), 3);
      expect(PicCtrlDataSet.baseCodeFor('Monochrome'), 4);
      expect(PicCtrlDataSet.baseCodeFor('Portrait'), 5);
      expect(PicCtrlDataSet.baseCodeFor('Flat Monochrome'), 9);
      expect(PicCtrlDataSet.baseCodeFor('Standard'), 1);
      expect(PicCtrlDataSet.baseCodeFor(null), 1);
    });
  });

  group('LUT conversion', () {
    test('identity curve converts to a ~identity 8-bit LUT', () {
      final lut = PicCtrlDataSet.lutFromToneCurve(ToneCurve.identity());
      expect(lut.length, 578);
      // Header
      expect(lut[0], 0x49);
      expect(lut[1], 0x30);
      expect(lut[2], 0); // input min
      expect(lut[3], 255); // input max
      expect(lut[4], 0);
      expect(lut[5], 255);
      expect(lut[6], 1); // gamma 1.0
      expect(lut[7], 0);
      expect(lut[8], 2); // two spline points
      expect(lut[9], 0);
      expect(lut[10], 0);
      expect(lut[11], 255);
      expect(lut[12], 255);

      final pts = PicCtrlDataSet(
        basePictureControl: 1,
        registrationName: 'x',
        customCurveFlag: true,
        lut: lut,
      ).readLut8()!;
      expect(pts.length, 257);
      expect(pts.first, 0);
      expect(pts[1], 1);
      expect(pts.last, 255);
      // monotonic non-decreasing
      for (var i = 1; i < pts.length; i++) {
        expect(pts[i] >= pts[i - 1], isTrue, reason: 'i=$i');
      }
    });

    test('rejects curves with too many points', () {
      expect(
        () => PicCtrlDataSet.lutFromToneCurve(ToneCurve(
          lut: List.filled(256, 0),
          points: List.generate(21, (i) => Point(i * 12, i * 12)),
        )),
        throwsArgumentError,
      );
    });
  });
}