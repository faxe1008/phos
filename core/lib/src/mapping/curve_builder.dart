import 'dart:math' as math;

import '../model/colors.dart';

/// Helpers that build NP3 tone curves from higher-level curve descriptions
/// (Lightroom point curves, parametric sliders).

abstract final class CurveBuilder {
  static const int _max = 32767;

  /// Build a [ToneCurve] from Lightroom-style control points (x,y in 0..255).
  ///
  /// The LUT is filled by piecewise-linear interpolation. NP3's LUT entry i
  /// is the 0..32767 output for 8-bit input i+1 (input 0 is implicitly 0), so
  /// we sample the control-point curve at input = i+1.
  static ToneCurve fromControlPoints(List<Point> rawPoints) {
    final (interp, np3Points) = _normalize(rawPoints);
    final lut = <int>[];
    var running = 0;
    for (var i = 0; i < 256; i++) {
      final input = (i + 1).clamp(0, 255).toDouble();
      final y = _interp(interp, input);
      var v = (y / 255 * _max).round();
      v = v.clamp(0, _max);
      if (v < running) v = running; // enforce monotonic non-decreasing
      running = v;
      lut.add(v);
    }
    return ToneCurve(lut: lut, points: np3Points);
  }

  /// True when [rawPoints] is the diagonal (identity) curve.
  static bool isIdentityCurve(String? xmpCurveString) {
    if (xmpCurveString == null) return true;
    final trimmed = xmpCurveString.trim();
    if (trimmed.isEmpty) return true;
    final pts = parseCurveString(trimmed);
    if (pts.isEmpty) return true;
    for (final p in pts) {
      if (p.x != p.y) return false;
    }
    return true;
  }

  /// Parse a Lightroom tone-curve string into [Point]s.
  ///
  /// Lightroom writes `"x y, x y, ..."` (points separated by commas,
  /// coordinates by whitespace); some third-party writers use `"x,y x,y"`.
  static List<Point> parseCurveString(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return const [];
    final out = <Point>[];
    for (final seg in trimmed.split(',')) {
      final parts = seg.trim().split(RegExp(r'\s+'));
      if (parts.length != 2) continue;
      final x = int.tryParse(parts[0]);
      final y = int.tryParse(parts[1]);
      if (x == null || y == null) continue;
      out.add(Point(x.clamp(0, 255), y.clamp(0, 255)));
    }
    if (out.isEmpty) {
      for (final pair in trimmed.split(RegExp(r'\s+'))) {
        final parts = pair.split(',');
        if (parts.length != 2) continue;
        final x = int.tryParse(parts[0].trim());
        final y = int.tryParse(parts[1].trim());
        if (x == null || y == null) continue;
        out.add(Point(x.clamp(0, 255), y.clamp(0, 255)));
      }
    }
    return out;
  }

  /// Sorts and de-duplicates [raw], then returns:
  ///
  ///   * the x-sorted table used to interpolate the LUT (anchored at (0,0) and
  ///     (255,255)), and
  ///   * the point list in NP3 chunk order (user points ascending, then the
  ///     white anchor (255,255) and finally the black anchor (0,0)).
  static (List<Point>, List<Point>) _normalize(List<Point> raw) {
    final byX = <int, Point>{};
    for (final p in raw) {
      byX[p.x.clamp(0, 255)] = Point(p.x.clamp(0, 255), p.y.clamp(0, 255));
    }
    var pts = byX.entries.map((e) => e.value).toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    if (pts.isEmpty) pts = [Point(0, 0), Point(255, 255)];
    if (pts.first.x != 0) pts = [Point(0, pts.first.y), ...pts];
    if (pts.last.x != 255) pts = [...pts, Point(255, pts.last.y)];

    final body = pts.where((p) => p.x != 0 && p.x != 255).toList();
    final np3Points = [...body, Point(255, 255), Point(0, 0)];
    return (pts, np3Points);
  }

  static double _interp(List<Point> pts, double x) {
    if (x <= pts.first.x) return pts.first.y.toDouble();
    final last = pts.lastWhere((p) => p.x <= x, orElse: () => pts.first);
    final idx = pts.indexOf(last);
    if (idx >= pts.length - 1) return pts.last.y.toDouble();
    final a = pts[idx];
    final b = pts[idx + 1];
    if (b.x == a.x) return b.y.toDouble();
    final h = <double>[];
    final delta = <double>[];
    for (var i = 1; i < pts.length; i++) {
      h.add((pts[i].x - pts[i - 1].x).toDouble());
      delta.add((pts[i].y - pts[i - 1].y) / h.last);
    }
    final d = _monotonicSlopes(h, delta);
    final t = (x - a.x) / (b.x - a.x);
    final y0 = a.y.toDouble();
    final y1 = b.y.toDouble();
    final m0 = d[idx] * h[idx];
    final m1 = d[idx + 1] * h[idx];
    final t2 = t * t;
    final t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * y0 +
        (t3 - 2 * t2 + t) * m0 +
        (-2 * t3 + 3 * t2) * y1 +
        (t3 - t2) * m1;
  }

  /// Fritsch-Carlson slopes: smooth between points without overshooting a
  /// monotonic segment, which keeps the exported camera LUT monotonic.
  static List<double> _monotonicSlopes(List<double> h, List<double> delta) {
    final d = List<double>.filled(delta.length + 1, 0);
    if (delta.length == 1) {
      d[0] = delta[0];
      d[1] = delta[0];
      return d;
    }
    for (var i = 1; i < delta.length; i++) {
      if (delta[i - 1] * delta[i] <= 0) {
        d[i] = 0;
      } else {
        final w1 = 2 * h[i] + h[i - 1];
        final w2 = h[i] + 2 * h[i - 1];
        d[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i]);
      }
    }
    d[0] = _endpointSlope(h[0], h[1], delta[0], delta[1]);
    d[d.length - 1] = _endpointSlope(
        h.last, h[h.length - 2], delta.last, delta[delta.length - 2]);
    return d;
  }

  static double _endpointSlope(double h0, double h1, double d0, double d1) {
    var out = ((2 * h0 + h1) * d0 - h0 * d1) / (h0 + h1);
    if (out * d0 <= 0) return 0;
    if (d0 * d1 < 0 && out.abs() > 3 * d0.abs()) out = 3 * d0;
    return out;
  }

  /// Build a curve by adding [highlightShift] to the upper half and
  /// [shadowShift] to the lower half of an identity LUT (Fujifilm-style).
  /// Shifts are in 0..32767 output units at the extreme end, tapering to 0 at
  /// the midpoint.
  static ToneCurve fromHighlightShadow(
      double highlightShift, double shadowShift) {
    final lut = <int>[];
    var running = 0;
    for (var i = 0; i < 256; i++) {
      final x = i + 1;
      final identity = (x / 256 * _max).round();
      double shift;
      if (x >= 128) {
        final taper = (x - 128) / 127;
        shift = highlightShift * taper;
      } else {
        final taper = (128 - x) / 128;
        shift = shadowShift * taper;
      }
      var v = (identity + shift).round();
      v = v.clamp(0, _max);
      if (v < running) v = running;
      running = v;
      lut.add(v);
    }
    return ToneCurve(lut: lut, points: const [Point(255, 255), Point(0, 0)]);
  }

  static int clampV(int v) => math.max(0, math.min(_max, v));
}
