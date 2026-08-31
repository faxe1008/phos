import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:phos_core/phos_core.dart';

/// Applies a [NikonParams] look to an [img.Image] as a *preview approximation*
/// of the in-camera rendering.
///
/// This is intentionally an approximation, not a bit-exact emulation of the
/// Z-body pipeline: it reproduces the visible character of each parameter
/// (tone, saturation, hue tinting, split-toning, sharpening) well enough that
/// a style's thumbnail reads the way the camera would apply it.
abstract final class NikonPreviewFilter {
  /// Apply [params] to [source], returning a new image.
  static img.Image apply(img.Image source, NikonParams params, {int? width}) {
    var img2 = source;
    if (width != null && source.width != width) {
      final h = (source.height * width / source.width).round();
      img2 = img.copyResize(
        source,
        width: width,
        height: h.clamp(1, 100000),
        interpolation: img.Interpolation.linear,
      );
    }

    final lut = buildMasterLut(params);
    final satFactor = (1 + (params.saturation ?? 0) / 100.0).clamp(0.0, 2.5);
    final (gr, gg, gb, addR, addG, addB) = _blenderGains(params.colorBlender);
    final grades = _gradeSetup(params);
    final blendScale =
        (params.gradingBlending ?? 50) / 50.0; // default 50 => 1.0

    for (var y = 0; y < img2.height; y++) {
      for (var x = 0; x < img2.width; x++) {
        final p = img2.getPixel(x, y);
        var r = lut[p.r.round()].toDouble();
        var g = lut[p.g.round()].toDouble();
        var b = lut[p.b.round()].toDouble();

        // Saturation: blend toward luma.
        final luma = 0.299 * r + 0.587 * g + 0.114 * b;
        r = luma + (r - luma) * satFactor;
        g = luma + (g - luma) * satFactor;
        b = luma + (b - luma) * satFactor;

        // Color blender gains.
        r *= gr;
        g *= gg;
        b *= gb;
        r += addR;
        g += addG;
        b += addB;

        // Split-toning style color grading. The tint scales with the zone's
        // chroma; the brightness shift applies on its own so a
        // brightness-only zone is visible.
        final l2 = 0.299 * r + 0.587 * g + 0.114 * b;
        for (final zd in grades) {
          final zw = zd.weight(l2) * blendScale;
          if (zw <= 0.001) continue;
          final w = zw * zd.strength;
          r += (zd.tintR - r) * w;
          g += (zd.tintG - g) * w;
          b += (zd.tintB - b) * w;
          if (zd.shift != 0) {
            r += zd.shift * zw;
            g += zd.shift * zw;
            b += zd.shift * zw;
          }
        }

        img2.setPixelRgb(
          x,
          y,
          r.clamp(0, 255).round(),
          g.clamp(0, 255).round(),
          b.clamp(0, 255).round(),
        );
      }
    }

    final sharp = (params.sharpening ?? 0).clamp(-3.0, 9.0);
    if (sharp != 0) {
      img2 = _unsharp(img2, amount: sharp / 9.0);
    }
    return img2;
  }

  // ------------------------------------------------------------------ LUT --

  /// 256-entry master tone LUT for [params]. A tone curve (when present)
  /// supersedes the tonal sliders, mirroring the NP3 sentinel behavior.
  static Uint8List buildMasterLut(NikonParams p) {
    var lut = List<int>.generate(256, (i) => i);
    final curve = p.toneCurve;
    if (curve != null && !curve.isIdentity) {
      for (var i = 0; i < 256; i++) {
        lut[i] = ((curve.lut[i] * 255) / 32767).round().clamp(0, 255);
      }
      return Uint8List.fromList(lut);
    }
    final c = p.contrast ?? 0;
    if (c != 0) {
      final f = 1 + c / 100.0 * 0.5;
      final nl = <int>[];
      for (var i = 0; i < 256; i++) {
        nl.add((128 + (i - 128) * f).round().clamp(0, 255));
      }
      lut = nl;
    }
    final hl = p.highlights ?? 0;
    final sh = p.shadows ?? 0;
    if (hl != 0 || sh != 0) {
      final nl = <int>[];
      for (var i = 0; i < 256; i++) {
        var v = i.toDouble();
        if (i > 128 && hl != 0) v += hl * ((i - 128) / 127);
        if (i < 128 && sh != 0) v += sh * ((128 - i) / 128);
        nl.add(v.round().clamp(0, 255));
      }
      lut = nl;
    }
    final wl = p.whiteLevel ?? 0;
    final bl = p.blackLevel ?? 0;
    if (wl != 0 || bl != 0) {
      final nl = <int>[];
      for (var i = 0; i < 256; i++) {
        var v = i.toDouble();
        if (i > 200 && wl != 0) v += wl * ((i - 200) / 55);
        if (i < 55 && bl != 0) v += bl * ((55 - i) / 55);
        nl.add(v.round().clamp(0, 255));
      }
      lut = nl;
    }
    return Uint8List.fromList(lut);
  }

  // ------------------------------------------------------------- helpers --

  static (double r, double g, double b, double addR, double addG, double addB)
  _blenderGains(Map<String, ColorChannel>? ch) {
    const dirs = {
      'red': (1.0, 0.15, 0.15),
      'orange': (1.0, 0.5, 0.1),
      'yellow': (0.9, 0.9, 0.1),
      'green': (0.15, 1.0, 0.2),
      'cyan': (0.1, 0.9, 0.9),
      'blue': (0.1, 0.2, 1.0),
      'purple': (0.7, 0.15, 0.9),
      'magenta': (0.9, 0.15, 0.7),
    };
    double dr = 0, dg = 0, db = 0, ar = 0, ag = 0, ab = 0;
    if (ch != null) {
      for (final e in ch.entries) {
        final d = dirs[e.key];
        if (d == null) continue;
        final c = e.value;
        final g = c.chroma / 100.0 * 0.35;
        dr += g * d.$1;
        dg += g * d.$2;
        db += g * d.$3;
        final br = c.brightness / 100.0 * 0.15;
        ar += br * d.$1;
        ag += br * d.$2;
        ab += br * d.$3;
      }
    }
    return (1 + dr, 1 + dg, 1 + db, ar * 100, ag * 100, ab * 100);
  }

  static List<_Zone> _gradeSetup(NikonParams p) {
    final zones = p.colorGrading;
    if (zones == null || zones.isEmpty) return const [];
    final out = <_Zone>[];
    const names = ['highlights', 'midtones', 'shadows'];
    for (final n in names) {
      final z = zones[n];
      if (z == null || z.isNeutral) continue;
      final (tr, tg, tb) = _hslToRgb(
        z.hue.toDouble(),
        (z.chroma.abs() / 100.0).clamp(0, 1),
      );
      out.add(
        _Zone(
          tintR: tr,
          tintG: tg,
          tintB: tb,
          shift: z.brightness / 100.0 * 0.3,
          strength: (z.chroma.abs() / 100.0).clamp(0, 1) * 0.6,
          weight: _zoneWeight(n),
        ),
      );
    }
    return out;
  }

  static double Function(double luma) _zoneWeight(String zone) {
    switch (zone) {
      case 'highlights':
        return (l) => _smoothstep(l, 150, 255);
      case 'shadows':
        return (l) => _smoothstep(l, 105, 0);
      default:
        return (l) => (1 - (l - 128).abs() / 128).clamp(0.0, 1.0);
    }
  }

  static double _smoothstep(double x, double e0, double e1) {
    if (e0 == e1) return x >= e0 ? 1 : 0;
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static (double, double, double) _hslToRgb(double h, double s) {
    h = (h % 360) / 360;
    final c = s * 0.5; // keep mid-lightness
    final x = c * (1 - ((h * 6) % 2 - 1).abs());
    final m = 0.5 - c;
    final (r, g, b) = switch (h * 6) {
      final h6 when h6 < 1 => (c, x, 0.0),
      final h6 when h6 < 2 => (x, c, 0.0),
      final h6 when h6 < 3 => (0.0, c, x),
      final h6 when h6 < 4 => (0.0, x, c),
      final h6 when h6 < 5 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    return (r + m, g + m, b + m);
  }

  /// Light unsharp mask: out = in + (in - blurred) * amount.
  static img.Image _unsharp(img.Image src, {required double amount}) {
    final blurred = img.gaussianBlur(src, radius: 1);
    final out = img.copyResize(
      src,
      width: src.width,
      height: src.height,
      interpolation: img.Interpolation.nearest,
    );
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final o = out.getPixel(x, y);
        final bl = blurred.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          (o.r + (o.r - bl.r) * amount).clamp(0, 255).round(),
          (o.g + (o.g - bl.g) * amount).clamp(0, 255).round(),
          (o.b + (o.b - bl.b) * amount).clamp(0, 255).round(),
        );
      }
    }
    return out;
  }
}

class _Zone {
  const _Zone({
    required this.tintR,
    required this.tintG,
    required this.tintB,
    required this.shift,
    required this.strength,
    required this.weight,
  });
  final double tintR, tintG, tintB, shift, strength;
  final double Function(double luma) weight;
}

/// Standard HSL → RGB in 0..1.
(double, double, double) hslToRgb(double h, double s, double l) {
  h = (h % 360) / 360;
  final c = (1 - (2 * l - 1).abs()) * s;
  final h6 = h * 6;
  final x = c * (1 - (h6 % 2 - 1).abs());
  final m = l - c / 2;
  final (r, g, b) = switch (h6) {
    final v when v < 1 => (c, x, 0.0),
    final v when v < 2 => (x, c, 0.0),
    final v when v < 3 => (0.0, c, x),
    final v when v < 4 => (0.0, x, c),
    final v when v < 5 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  return (r + m, g + m, b + m);
}

/// Generate a colorful test card (960x600) used as the default preview base,
/// so the app works before the user picks their own photo.
img.Image generateDefaultPreviewCard() {
  const w = 960, h = 600;
  final img2 = img.Image(width: w, height: h, numChannels: 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final u = x / w;
      final v = y / h;
      final hue = (u * 300 + v * 90) % 360;
      final light = 0.25 + 0.6 * (1 - v);
      final (r, g, b) = hslToRgb(hue, 0.6, light);
      img2.setPixelRgb(x, y, r.round(), g.round(), b.round());
    }
  }
  return img2;
}
