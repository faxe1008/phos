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
    var pts = byX.entries
        .map((e) => e.value)
        .toList()
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
    final t = (x - a.x) / (b.x - a.x);
    return a.y + t * (b.y - a.y);
  }

  /// Build a curve by adding [highlightShift] to the upper half and
  /// [shadowShift] to the lower half of an identity LUT (Fujifilm-style).
  /// Shifts are in 0..32767 output units at the extreme end, tapering to 0 at
  /// the midpoint.
  static ToneCurve fromHighlightShadow(double highlightShift, double shadowShift) {
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