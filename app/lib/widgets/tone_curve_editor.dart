import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../theme/app_theme.dart';

/// Interactive 2D editor for a tone curve's mid control points.
///
/// The corner anchors (0,0) and (255,255) are fixed. Tapping an empty spot
/// adds a point, dragging a point moves it (clamped between its neighbours
/// so the curve stays monotonic), double-tapping a point removes it. The
/// NP3 chunk caps the total at 20 points including anchors.
class ToneCurveEditor extends StatefulWidget {
  const ToneCurveEditor({
    super.key,
    required this.points,
    required this.onChanged,
    this.size = 220,
  });

  /// Mid control points (0 < x < 255), any order.
  final List<Point> points;

  /// Called with the new mid control points after every change.
  final ValueChanged<List<Point>> onChanged;

  final double size;

  static const int maxUserPoints = Np3ToneCurveChunk.maxPoints - 2;

  @override
  State<ToneCurveEditor> createState() => _ToneCurveEditorState();
}

class _ToneCurveEditorState extends State<ToneCurveEditor> {
  late List<Point> _points;
  int? _dragIndex;
  int? _pendingGrab;
  int _generation = 0;
  final GlobalKey _boxKey = GlobalKey();

  static const Point _black = Point(0, 0);
  static const Point _white = Point(255, 255);

  static List<Point> _userPoints(Iterable<Point> pts) =>
      pts
          .where((p) => p.x > 0 && p.x < 255)
          .map((p) => Point(p.x, p.y))
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x));

  @override
  void initState() {
    super.initState();
    _points = _userPoints(widget.points);
  }

  @override
  void didUpdateWidget(ToneCurveEditor old) {
    super.didUpdateWidget(old);
    // Re-sync only when the parent passed a different list and its content
    // differs from the one being edited (an external change, e.g. the curve
    // was removed). Our own onChanged round-trips equal content, and a
    // parent that never echoes state passes the same list instance.
    if (identical(old.points, widget.points)) return;
    final incoming = _userPoints(widget.points);
    if (!_same(incoming, _points)) {
      _points = incoming;
      _dragIndex = null;
    }
  }

  static bool _same(List<Point> a, List<Point> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _emit() {
    _generation++;
    widget.onChanged(List.of(_points));
  }

  Offset _local(Offset global) {
    final ctx = _boxKey.currentContext;
    if (ctx == null) return global;
    return (ctx.findRenderObject() as RenderBox).globalToLocal(global);
  }

  Point _toPoint(Offset local) {
    final s = widget.size;
    final x = (local.dx / s * 255).round().clamp(1, 254);
    final y = ((1 - local.dy / s) * 255).round().clamp(0, 255);
    return Point(x, y);
  }

  int? _hit(Offset local) {
    var best = -1;
    var bestDist = 16.0;
    for (var i = 0; i < _points.length; i++) {
      final p = _points[i];
      final d =
          (Offset(p.x / 255 * widget.size, (1 - p.y / 255) * widget.size) -
                  local)
              .distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best == -1 ? null : best;
  }

  void _add(Point p) {
    if (_points.length >= ToneCurveEditor.maxUserPoints) return;
    if (_points.any((q) => q.x == p.x)) return;
    final idx = _points.indexWhere((q) => q.x > p.x);
    final prev = idx < 0 ? _black : _points[idx - 1];
    final next = idx < 0 ? _white : _points[idx];
    final y = p.y.clamp(prev.y, next.y);
    _points.insert(idx < 0 ? _points.length : idx, Point(p.x, y));
    _emit();
  }

  void _onTapDown(TapDownDetails d) {
    final local = _local(d.globalPosition);
    final hit = _hit(local);
    if (hit != null) {
      _dragIndex = hit;
    } else {
      _add(_toPoint(local));
    }
  }

  // The grab must be resolved at pointer-down: once a pan wins the arena,
  // the pointer is already past the touch slop, so a hit test at the win
  // position misses the point under the finger.
  void _onPanDown(DragDownDetails d) {
    _pendingGrab = _hit(_local(d.globalPosition));
  }

  void _onPanStart(DragStartDetails d) {
    _dragIndex ??= _pendingGrab;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final i = _dragIndex;
    if (i == null) return;
    final p = _toPoint(_local(d.globalPosition));
    final prev = i > 0 ? _points[i - 1] : _black;
    final next = i < _points.length - 1 ? _points[i + 1] : _white;
    final xLo = prev.x + 1;
    final xHi = next.x - 1;
    final x = xLo > xHi ? _points[i].x : p.x.clamp(xLo, xHi);
    final y = p.y.clamp(prev.y, next.y);
    if (x == _points[i].x && y == _points[i].y) return;
    _points[i] = Point(x, y);
    _emit();
  }

  void _onDoubleTapDown(TapDownDetails d) {
    final hit = _hit(_local(d.globalPosition));
    if (hit == null) return;
    _points.removeAt(hit);
    _dragIndex = null;
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      // A plain tap on a point (grabbed in _onTapDown) must not leave a
      // stale drag index behind.
      onTapUp: (_) {
        _pendingGrab = null;
        setState(() => _dragIndex = null);
      },
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanDown: _onPanDown,
      onPanEnd: (_) {
        _pendingGrab = null;
        setState(() => _dragIndex = null);
      },
      onDoubleTapDown: _onDoubleTapDown,
      child: SizedBox(
        key: _boxKey,
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _CurvePainter(
            points: _points,
            dragIndex: _dragIndex,
            size: widget.size,
            generation: _generation,
          ),
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.points,
    required this.dragIndex,
    required this.size,
    required this.generation,
  });

  final List<Point> points;
  final int? dragIndex;
  final double size;
  final int generation;

  @override
  void paint(Canvas canvas, Size sz) {
    final s = sz.width;

    final bg = Paint()..color = AppTheme.surfaceHigh;
    canvas.drawRect(Offset.zero & Size(s, s), bg);

    final grid = Paint()
      ..color = AppTheme.hairline
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final v = s * i / 4;
      canvas.drawLine(Offset(v, 0), Offset(v, s), grid);
      canvas.drawLine(Offset(0, v), Offset(s, v), grid);
    }

    final diag = Paint()
      ..color = AppTheme.textTertiary.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, s), Offset(s, 0), diag);

    Offset px(Point p) => Offset(p.x / 255 * s, (1 - p.y / 255) * s);

    final path = Path();
    var cur = px(const Point(0, 0));
    path.moveTo(cur.dx, cur.dy);
    final all = [const Point(0, 0), ...points, const Point(255, 255)];
    final slopes = _slopes(all);
    for (var i = 0; i < all.length - 1; i++) {
      final a = all[i];
      final b = all[i + 1];
      final h = (b.x - a.x).toDouble();
      if (h <= 0) continue;
      final p0 = px(a);
      final p1 = px(b);
      final m0 = slopes[i] * h;
      final m1 = slopes[i + 1] * h;
      path.cubicTo(
        p0.dx + h / 3 * s / 255,
        p0.dy - m0 / 3 * s / 255,
        p1.dx - h / 3 * s / 255,
        p1.dy + m1 / 3 * s / 255,
        p1.dx,
        p1.dy,
      );
    }
    final stroke = Paint()
      ..color = AppTheme.seed
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);

    final anchor = Paint()..color = AppTheme.textTertiary;
    final dot = Paint()..color = AppTheme.seed;
    for (final p in [const Point(0, 0), const Point(255, 255)]) {
      canvas.drawCircle(px(p), 3.5, anchor);
    }
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(px(points[i]), i == dragIndex ? 7 : 5, dot);
    }
  }

  List<double> _slopes(List<Point> pts) {
    final h = <double>[];
    final delta = <double>[];
    for (var i = 1; i < pts.length; i++) {
      h.add((pts[i].x - pts[i - 1].x).toDouble());
      delta.add((pts[i].y - pts[i - 1].y) / h.last);
    }
    final d = List<double>.filled(pts.length, 0);
    if (delta.length == 1) return [delta[0], delta[0]];
    for (var i = 1; i < delta.length; i++) {
      if (delta[i - 1] * delta[i] > 0) {
        final w1 = 2 * h[i] + h[i - 1];
        final w2 = h[i] + 2 * h[i - 1];
        d[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i]);
      }
    }
    d[0] = delta[0];
    d[d.length - 1] = delta.last;
    return d;
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.generation != generation || old.dragIndex != dragIndex;
}
