import 'dart:io';

import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

XmpMeta _xmp(String name) =>
    XmpParser.parse(File('test/fixtures/xmp/$name').readAsBytesSync());

void main() {
  group('xmp -> nikon (basic-pv2)', () {
    late NikonParams n;
    late MappingReport report;
    setUpAll(() {
      final (n1, r1) = XmpToNikon.convert(_xmp('basic-pv2.xmp'), name: 'Test');
      n = n1;
      report = r1;
    });

    test('contrast rescaled pv2: 30 -> 20', () {
      expect(n.contrast, 20);
      final row = report.fields.firstWhere((f) => f.sourceField == 'xmp.contrast');
      expect(row.status, MappingStatus.scaled);
    });

    test('highlight/shadow/white/black 1:1', () {
      expect(n.highlights, -20);
      expect(n.shadows, 15);
      expect(n.whiteLevel, 10);
      expect(n.blackLevel, -5);
    });

    test('saturation 1:1, vibrance folded at 50%', () {
      // -12 + round(8 * 0.5) = -8
      expect(n.saturation, -8);
      final row = report.fields.firstWhere((f) => f.sourceField == 'xmp.vibrance');
      expect(row.status, MappingStatus.approximated);
    });

    test('sharpenDetail 40 -> 3.6, clarity 20 -> 1.0', () {
      expect(n.sharpening, 3.6);
      expect(n.clarity, 1.0);
    });

    test('WB, radius, masking reported unsupported / kept out of NP3', () {
      expect(
          report.fields.any((f) =>
              f.sourceField == 'xmp.whiteBalance' &&
              f.status == MappingStatus.unsupported),
          isTrue);
      expect(
          report.fields.any((f) =>
              f.sourceField == 'xmp.sharpenRadius' &&
              f.status == MappingStatus.unsupported),
          isTrue);
    });

    test('report has a mapping version', () {
      expect(report.mappingVersion, XmpToNikon.version);
      expect(report.overall, isNotNull);
      expect(report.summary, isNotEmpty);
    });
  });

  group('xmp -> nikon (curve + HSL + color grade)', () {
    late NikonParams n;
    late MappingReport report;
    setUpAll(() {
      final (n1, r1) =
          XmpToNikon.convert(_xmp('curve-hsl-colorgrade.xmp'), name: 'Test');
      n = n1;
      report = r1;
    });

    test('custom curve supersedes the tonal sliders', () {
      expect(n.toneCurve, isNotNull);
      expect(n.contrast, null);
      expect(n.highlights, null);
      expect(n.shadows, null);
      final superseded =
          report.fields.where((f) => f.status == MappingStatus.superseded);
      expect(superseded.length, greaterThanOrEqualTo(4));
    });

    test('HSL -> color blender with hue scaling', () {
      final red = n.colorBlender!['red']!;
      expect(red.hue, (-12 * 100 / 180).round()); // -7
      expect(red.chroma, 8);
      expect(red.brightness, -6);
      expect(n.colorBlender!['green']!.chroma, 15);
    });

    test('new color grade -> grading zones (sat recentered)', () {
      final mid = n.colorGrading!['midtones']!;
      expect(mid.hue, 35);
      expect(mid.chroma, (62 - 50) * 2); // 24
      expect(mid.brightness, 2);
      expect(n.colorGrading!['shadows']!.hue, 200);
      expect(n.colorGrading!['shadows']!.chroma, (45 - 50) * 2); // -10
      expect(n.colorGrading!['highlights']!.hue, 50);
    });
  });

  group('xmp -> nikon (legacy split toning)', () {
    late NikonParams n;
    late MappingReport report;
    setUpAll(() {
      final (n1, r1) =
          XmpToNikon.convert(_xmp('legacy-split-toning.xmp'), name: 'Test');
      n = n1;
      report = r1;
    });

    test('pv1 contrast x2: 20 -> 40', () {
      expect(n.contrast, 40);
    });

    test('split toning approximated as grading zones', () {
      expect(n.colorGrading, isNotNull);
      final shadow = n.colorGrading!['shadows']!;
      expect(shadow.hue, 250);
      expect(shadow.chroma, 25);
      final high = n.colorGrading!['highlights']!;
      expect(high.hue, 40);
      expect(high.chroma, 15);
      expect(
          report.fields.any((f) => f.status == MappingStatus.approximated),
          isTrue);
    });

    test('legacy sharpening 40 approximated', () {
      expect(n.sharpening, isNotNull);
      expect(n.sharpening, greaterThan(0));
    });

    test('grain and vignette unsupported', () {
      expect(
          report.fields
              .where((f) => f.sourceField.startsWith('xmp.grain'))
              .length,
          greaterThan(0));
      expect(
          report.fields.any((f) =>
              f.sourceField == 'xmp.vignetteAmount' &&
              f.status == MappingStatus.unsupported),
          isTrue);
    });
  });
}