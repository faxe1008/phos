import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:phos_core/phos_core.dart';
import 'package:phos/preview/nikon_filter.dart';

img.Image _solid(int r, int g, int b, {int w = 32, int h = 32}) {
  final im = img.Image(width: w, height: h, numChannels: 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgb(x, y, r, g, b);
    }
  }
  return im;
}

void main() {
  group('buildMasterLut', () {
    test('neutral params give identity LUT', () {
      final lut = NikonPreviewFilter.buildMasterLut(NikonParams());
      for (var i = 0; i < 256; i++) {
        expect(lut[i], i);
      }
    });

    test('contrast lifts mids', () {
      final lut = NikonPreviewFilter
          .buildMasterLut(NikonParams(contrast: 50));
      expect(lut[10], lessThan(10));
      expect(lut[245], greaterThan(245));
    });

    test('tone curve supersedes sliders', () {
      final curve = ToneCurve(
        lut: List.filled(256, 32767),
        points: const [Point(0, 0), Point(255, 255)],
      );
      final lut = NikonPreviewFilter
          .buildMasterLut(NikonParams(toneCurve: curve, contrast: 50));
      expect(lut[0], 255);
      expect(lut[128], 255);
      expect(lut[255], 255);
    });
  });

  group('apply', () {
    test('neutral params change a gray image only slightly', () {
      final out = NikonPreviewFilter.apply(
          _solid(128, 128, 128), NikonParams());
      expect(out.getPixel(5, 5).r, closeTo(128, 2));
    });

    test('full desaturation grays out red', () {
      final out = NikonPreviewFilter.apply(
          _solid(200, 30, 30), NikonParams(saturation: -100));
      final p = out.getPixel(5, 5);
      expect((p.r - p.g).abs(), lessThan(6));
      expect((p.g - p.b).abs(), lessThan(6));
    });

    test('saturation boost increases channel spread on red', () {
      final boosted = NikonPreviewFilter.apply(
          _solid(200, 30, 30), NikonParams(saturation: 50));
      final p = boosted.getPixel(5, 5);
      final spread = (p.r - (p.g + p.b) / 2);
      expect(spread, greaterThan(40));
    });

    test('sharpening runs without error', () {
      final out = NikonPreviewFilter.apply(
          _solid(128, 128, 128), NikonParams(sharpening: 5));
      expect(out.width, 32);
    });
  });

  group('hslToRgb', () {
    test('pure hues', () {
      var (r0, g0, b0) = hslToRgb(0, 1, 0.5);
      expect(r0, closeTo(1, 1e-9));
      expect(g0, closeTo(0, 1e-9));
      expect(b0, closeTo(0, 1e-9));

      var (r1, g1, b1) = hslToRgb(120, 1, 0.5);
      expect(r1, closeTo(0, 1e-9));
      expect(g1, closeTo(1, 1e-9));
      expect(b1, closeTo(0, 1e-9));

      var (r2, g2, b2) = hslToRgb(240, 1, 0.5);
      expect(r2, closeTo(0, 1e-9));
      expect(g2, closeTo(0, 1e-9));
      expect(b2, closeTo(1, 1e-9));
    });

    test('grays for zero saturation', () {
      final (r, g, b) = hslToRgb(40, 0, 0.3);
      expect((r - g).abs(), lessThan(1e-9));
      expect((g - b).abs(), lessThan(1e-9));
      expect(r, closeTo(0.3, 1e-9));
    });
  });
}