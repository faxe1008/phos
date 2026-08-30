import 'dart:io';

import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

void main() {
  late FujiMeta f;
  late NikonParams n;
  late MappingReport report;

  setUpAll(() {
    final text = File('test/fixtures/fuji/classic_chrome.txt').readAsStringSync();
    f = FujiRecipeParser.parse(text);
    final (n1, r1) = FujiToNikon.convert(f, name: 'Classic Chrome');
    n = n1;
    report = r1;
  });

  test('color +2 -> saturation 50', () {
    expect(n.saturation, 50);
  });

  test('sharpness +1 -> 2.25 (asymmetric positive scale)', () {
    expect(n.sharpening, 2.25);
  });

  test('clarity 1:1', () {
    expect(n.clarity, 3.0);
  });

  test('highlight +1 with DR200 bias -0.5 -> 13', () {
    expect(n.highlights, 13);
  });

  test('shadow -2 -> -50', () {
    expect(n.shadows, -50);
  });

  test('color chrome strong -> red/orange chroma boost', () {
    expect(n.colorBlender!['red']!.chroma, 20);
    expect(n.colorBlender!['orange']!.chroma, 10);
  });

  test('color chrome blue weak -> blue/cyan boost', () {
    expect(n.colorBlender!['blue']!.chroma, 10);
    expect(n.colorBlender!['blue']!.brightness, -5);
    expect(n.colorBlender!['cyan']!.chroma, 5);
  });

  test('WB shift +2R/-5B -> warm midtone grade', () {
    final mid = n.colorGrading!['midtones']!;
    expect(mid.hue, 35);
    expect(mid.chroma, 11);
  });

  test('base profile hint for Classic Chrome is Standard', () {
    expect(n.baseProfileHint, 'Standard');
  });

  test('camera settings reported unsupported', () {
    for (final src in [
      'fuji.grainEffect',
      'fuji.noiseReduction',
      'fuji.iso',
      'fuji.exposureComp',
      'fuji.whiteBalanceMode',
    ]) {
      expect(
          report.fields.any((f) => f.sourceField == src),
          isTrue,
          reason: 'missing unsupported row for $src');
    }
  });
}