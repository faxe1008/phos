import 'dart:io';

import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

XmpMeta parseFixture(String name) =>
    XmpParser.parse(File('test/fixtures/xmp/$name').readAsBytesSync());

void main() {
  test('basic-pv2: develop settings, WB, detail', () {
    final m = parseFixture('basic-pv2.xmp');
    expect(m.name, 'Everyday Balanced');
    expect(m.description, contains('balanced everyday'));
    expect(m.author, 'phos-test');
    expect(m.processVersion, 11);
    expect(m.whiteBalance, isNotNull);
    expect(m.whiteBalance!.mode, 'Daylight');
    expect(m.whiteBalance!.temperature, 5450);
    expect(m.whiteBalance!.tint, 12);
    expect(m.contrast, 30);
    expect(m.highlights, -20);
    expect(m.shadows, 15);
    expect(m.whites, 10);
    expect(m.blacks, -5);
    expect(m.vibrance, 8);
    expect(m.saturation, -12);
    expect(m.clarity, 20);
    expect(m.sharpenDetail, 40);
    expect(m.sharpenRadius, 1.0);
    expect(m.sharpenEdgeMasking, 50);
  });

  test('curve-hsl-colorgrade: curve string, HSL, color grade', () {
    final m = parseFixture('curve-hsl-colorgrade.xmp');
    expect(m.name, 'Curve + Grade');
    expect(m.processVersion, 11);
    expect(m.toneCurve, '0 0, 18 14, 64 60, 128 132, 200 205, 255 255');

    final red = m.hsl![XmpHslColor.red]!;
    expect(red.hue, -12);
    expect(red.saturation, 8);
    expect(red.luminance, -6);
    expect(m.hsl![XmpHslColor.green]!.saturation, 15);
    expect(m.hsl![XmpHslColor.blue]!.luminance, 4);

    final mid = m.colorGradeMid!;
    expect(mid.hue, 35);
    expect(mid.saturation, 62);
    expect(mid.luminance, 2);
    expect(m.colorGradeShadow!.hue, 200);
    expect(m.colorGradeShadow!.saturation, 45);
    expect(m.colorGradeHigh!.hue, 50);
    expect(m.colorGradeHigh!.saturation, 58);
  });

  test('legacy-split-toning: pv1, split toning, unsupported extras', () {
    final m = parseFixture('legacy-split-toning.xmp');
    expect(m.name, 'Legacy Split');
    expect(m.processVersion, 1);
    expect(m.contrast, 20);
    expect(m.highlights, -30);
    expect(m.saturation, -25);
    expect(m.splitToningShadowHue, 250);
    expect(m.splitToningShadowSaturation, 25);
    expect(m.splitToningHighlightHue, 40);
    expect(m.splitToningHighlightSaturation, 15);
    expect(m.splitToningBalance, 5);
    expect(m.sharpening, 40);
    expect(m.grainAmount, 15);
    expect(m.vignetteAmount, -10);
  });

  test('XMP generator round-trips a parsed preset', () {
    final m = parseFixture('basic-pv2.xmp');
    final bytes = XmpGenerator.generateBytes(m);
    final m2 = XmpParser.parse(bytes);
    expect(m2.contrast, m.contrast);
    expect(m2.highlights, m.highlights);
    expect(m2.shadows, m.shadows);
    expect(m2.whiteBalance!.temperature, m.whiteBalance!.temperature);
    expect(m2.whiteBalance!.tint, m.whiteBalance!.tint);
    expect(m2.saturation, m.saturation);
    expect(m2.clarity, m.clarity);
    expect(m2.name, m.name);
  });
}