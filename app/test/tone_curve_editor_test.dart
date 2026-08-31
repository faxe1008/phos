import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phos_core/phos_core.dart';
import 'package:phos/widgets/tone_curve_editor.dart';

void main() {
  const size = 200.0;

  testWidgets('tap adds a point, drag moves it, double-tap removes it',
      (tester) async {
    final recorded = <List<Point>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ToneCurveEditor(
              points: const [],
              onChanged: (pts) => recorded.add(List.of(pts)),
              size: size,
            ),
          ),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(ToneCurveEditor));

    // Tap the centre: x = round(0.5*255) = 128, y = 128. The tap recognizer
    // only wins the arena once the double-tap window (300ms) has closed.
    await tester.tapAt(origin + const Offset(size / 2, size / 2));
    await tester.pump(const Duration(milliseconds: 350));
    expect(recorded, [
      [const Point(128, 128)]
    ]);

    // Drag 40px up: y = round((1 - 60/200) * 255) = 179. The move that wins
    // the arena is swallowed, so the drag happens in two steps.
    final gesture = await tester.startGesture(origin + const Offset(100, 100));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(recorded.last, [const Point(128, 179)]);

    // Double-tap the point where it now sits:
    // (128/255*200, (1 - 179/255)*200) = (100.4, 59.6).
    final atPoint = origin + const Offset(100.4, 59.6);
    final first = await tester.startGesture(atPoint);
    await first.up();
    await tester.pump(const Duration(milliseconds: 50));
    final second = await tester.startGesture(atPoint);
    await second.up();
    await tester.pump();
    expect(recorded.last, isEmpty);

    // Let the double-tap tracker's 40ms countdown expire.
    await tester.pump(const Duration(milliseconds: 60));
  });

  testWidgets('moves stay monotonic: a point cannot cross its neighbours',
      (tester) async {
    final recorded = <List<Point>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ToneCurveEditor(
              points: const [Point(64, 100), Point(192, 150)],
              onChanged: (pts) => recorded.add(List.of(pts)),
              size: size,
            ),
          ),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(ToneCurveEditor));

    // The (64,100) point sits at (50.2, 121.6). Drag it far down-left —
    // it must clamp against the black anchor (y >= 0) and the (192,150)
    // neighbour stays above it in x.
    final gesture =
        await tester.startGesture(origin + const Offset(50.2, 121.6));
    await tester.pump();
    await gesture.moveBy(const Offset(-20, 60));
    await tester.pump();
    await gesture.moveBy(const Offset(-20, 60));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // Let the double-tap tracker's 40ms countdown expire.
    await tester.pump(const Duration(milliseconds: 60));

    final last = recorded.last;
    expect(last[0].x, greaterThan(0));
    expect(last[0].y, lessThanOrEqualTo(150));
    expect(last[1], const Point(192, 150));

    // The LUT built from the result must be monotonic.
    final lut = CurveBuilder.fromControlPoints(last).lut;
    for (var i = 1; i < lut.length; i++) {
      expect(lut[i], greaterThanOrEqualTo(lut[i - 1]));
    }
  });
}