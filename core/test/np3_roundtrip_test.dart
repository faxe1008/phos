import 'dart:io';

import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

void expectSameParams(NikonParams a, NikonParams b) {
  expect(b.name, a.name, reason: 'name');
  expect(b.comment, a.comment, reason: 'comment');
  // Tonal sliders are compared in the canonical block below (a sentinel file
  // stores null; regenerating an identity curve stores 0).
  expect(b.saturation, a.saturation, reason: 'saturation');
  expect(b.sharpening, a.sharpening, reason: 'sharpening');
  expect(b.midRangeSharpening, a.midRangeSharpening, reason: 'midRangeSharpening');
  expect(b.clarity, a.clarity, reason: 'clarity');
  expect(b.gradingBlending, a.gradingBlending, reason: 'gradingBlending');
  expect(b.gradingBalance, a.gradingBalance, reason: 'gradingBalance');

  final ca = a.colorBlender ?? const <String, ColorChannel>{};
  final cb = b.colorBlender ?? const <String, ColorChannel>{};
  for (final name in ColorChannel.channelNames) {
    expect(cb[name], ca[name], reason: 'blender.$name');
  }
  final ga = a.colorGrading ?? const <String, GradingZone>{};
  final gb = b.colorGrading ?? const <String, GradingZone>{};
  for (final name in GradingZone.zoneNames) {
    expect(gb[name], ga[name], reason: 'grading.$name');
  }

  // An identity curve is canonicalized away by the generator (it writes plain
  // sliders instead of the sentinel + chunk), so compare in that canonical
  // form: identity curve == no curve, sliders at their stored-or-zero values.
  final aHas = a.toneCurve != null && !a.toneCurve!.isIdentity;
  final bHas = b.toneCurve != null && !b.toneCurve!.isIdentity;
  expect(bHas, aHas, reason: 'toneCurve presence (canonical)');
  if (aHas) {
    expect(b.toneCurve!.lut, a.toneCurve!.lut, reason: 'toneCurve.lut');
    expect(b.toneCurve!.points.length, a.toneCurve!.points.length,
        reason: 'toneCurve.points.length');
    for (var i = 0; i < a.toneCurve!.points.length; i++) {
      expect(b.toneCurve!.points[i], a.toneCurve!.points[i],
          reason: 'toneCurve.points[$i]');
    }
    expect(b.contrast, null, reason: 'sentinel must null contrast');
  } else {
    expect(b.contrast, a.contrast ?? 0, reason: 'contrast');
    expect(b.highlights, a.highlights ?? 0, reason: 'highlights');
    expect(b.shadows, a.shadows ?? 0, reason: 'shadows');
    expect(b.whiteLevel, a.whiteLevel ?? 0, reason: 'whiteLevel');
    expect(b.blackLevel, a.blackLevel ?? 0, reason: 'blackLevel');
  }
}

/// parse -> generate -> parse preserves the model.
void expectRoundTrip(File f) {
  final bytes = f.readAsBytesSync();
  final a = Np3Codec.parse(bytes);
  final regenerated = Np3Codec.generate(a);
  final b = Np3Codec.parse(regenerated);
  expectSameParams(a, b);
}

void main() {
  final dir = Directory('test/fixtures/np3');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.NP3'))
      .toList()
    ..sort((x, y) => x.path.compareTo(y.path));

  test('fixtures exist', () {
    expect(files.length, greaterThanOrEqualTo(10),
        reason: 'expected the vendored sssota sample set');
  });

  for (final f in files) {
    final name = f.uri.pathSegments.last;
    test('parses: $name', () {
      final p = Np3Codec.parse(f.readAsBytesSync());
      expect(p, isNotNull);
    });

    test('round-trips (model-stable): $name', () {
      expectRoundTrip(f);
    });
  }

  test('vanilla: generate(parse) is byte-identical', () {
    final bytes = File('test/fixtures/np3/vanilla.NP3').readAsBytesSync();
    final p = Np3Codec.parse(bytes);
    final out = Np3Codec.generate(p);
    expect(out, bytes, reason: 'vanilla must round-trip byte-for-byte');
  });

  test('curve samples: sliders are nulled by the sentinel', () {
    for (final name in [
      'tonecurve-black.NP3',
      'tonecurve-white.NP3',
      'tonecurve-max-point.NP3',
      'comment-a-tonecurve.NP3',
    ]) {
      final p = Np3Codec.parse(File('test/fixtures/np3/$name').readAsBytesSync());
      expect(p.toneCurve, isNotNull, reason: '$name should carry a curve');
      expect(p.contrast, null, reason: '$name contrast should be nulled');
      expect(p.highlights, null, reason: '$name highlights should be nulled');
      expect(p.shadows, null, reason: '$name shadows should be nulled');
      expect(p.whiteLevel, null, reason: '$name whiteLevel should be nulled');
      expect(p.blackLevel, null, reason: '$name blackLevel should be nulled');
    }
  });

  test('tonecurve-noop is the identity curve', () {
    final p =
        Np3Codec.parse(File('test/fixtures/np3/tonecurve-noop.NP3').readAsBytesSync());
    expect(p.toneCurve, isNotNull);
    expect(p.toneCurve!.isIdentity, isTrue,
        reason: 'noop curve must equal the identity LUT');
  });

  test('comment samples carry non-empty comments', () {
    for (final name in [
      'comment-a.NP3',
      'comment-ab.NP3',
      'comment-abcde.NP3',
      'longest-comment.NP3',
    ]) {
      final p = Np3Codec.parse(File('test/fixtures/np3/$name').readAsBytesSync());
      expect(p.comment, isNotNull, reason: '$name should have a comment');
      expect(p.comment, isNotEmpty, reason: '$name comment should be non-empty');
    }
  });

  test('bad magic is rejected', () {
    expect(() => Np3Codec.parse(List<int>.filled(32, 0)),
        throwsA(isA<FormatException>()));
  });
}