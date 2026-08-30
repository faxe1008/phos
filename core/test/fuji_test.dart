import 'dart:io';

import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

void main() {
  final text = File('test/fixtures/fuji/classic_chrome.txt').readAsStringSync();
  final f = FujiRecipeParser.parse(text);

  test('film simulation from bare first line', () {
    expect(f.filmSimulation, 'Classic Chrome');
  });

  test('dynamic range normalized', () {
    expect(f.dynamicRange, 'DR200');
  });

  test('tone and color adjustments', () {
    expect(f.highlightTone, 1);
    expect(f.shadowTone, -2);
    expect(f.color, 2);
    expect(f.noiseReduction, -4);
    expect(f.sharpness, 1);
    expect(f.clarity, 3);
  });

  test('grain split into strength and size', () {
    expect(f.grainStrength, 'Weak');
    expect(f.grainSize, 'Small');
  });

  test('color chrome effects', () {
    expect(f.colorChromeEffect, 'Strong');
    expect(f.colorChromeEffectBlue, 'Weak');
  });

  test('white balance mode and shifts', () {
    expect(f.whiteBalanceMode, 'Daylight');
    expect(f.wbRedShift, 2);
    expect(f.wbBlueShift, -5);
  });

  test('iso and exposure kept as strings (unsupported)', () {
    expect(f.iso, 'Auto, up to ISO 6400');
    expect(f.exposureComp, '0 to +2/3 (typically)');
  });

  test('empty input yields an empty meta', () {
    final e = FujiRecipeParser.parse('');
    expect(e.filmSimulation, isNull);
    expect(e.color, isNull);
  });

  group('film.recipes label variants', () {
    final fr = FujiRecipeParser.parse('''
Film Simulation: Classic Chrome
Grain Effect: Weak, Small
Col. Chr. Effect: Weak
Col. Chr. Blue: Off
White Balance: Daylight, +4 Red, \u20115 Blue
Dynamic Range: DR200
Highlights: \u20111
Shadows: 1
Colour: 1
Sharpness: \u20112
ISO N.R.: \u20114
Clarity: 0
EV Comp.: +1/3
''');

    test('colour / col. chr. / iso n.r. / ev comp. aliases', () {
      expect(fr.filmSimulation, 'Classic Chrome');
      expect(fr.dynamicRange, 'DR200');
      expect(fr.highlightTone, -1);
      expect(fr.shadowTone, 1);
      expect(fr.color, 1);
      expect(fr.sharpness, -2);
      expect(fr.noiseReduction, -4);
      expect(fr.clarity, 0);
      expect(fr.colorChromeEffect, 'Weak');
      expect(fr.colorChromeEffectBlue, 'Off');
      expect(fr.exposureComp, '+1/3');
    });

    test('unicode minus signs normalize in numbers and WB shifts', () {
      expect(fr.whiteBalanceMode, 'Daylight');
      expect(fr.wbRedShift, 4);
      expect(fr.wbBlueShift, -5);
    });
  });
}