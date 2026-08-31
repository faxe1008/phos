import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phos/widgets/color_wheel.dart';

void main() {
  testWidgets('wheel coordinates match displayed hue orientation', (
    tester,
  ) async {
    final values = <({double hue, double chroma})>[];
    const size = 200.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ColorWheel(
              hue: 0,
              chroma: 0,
              size: size,
              onChanged: values.add,
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(ColorWheel));
    await tester.tapAt(center + const Offset(0, -80));
    expect(values.last.hue, closeTo(0, 1));
    expect(values.last.chroma, closeTo(80, 1));

    await tester.tapAt(center + const Offset(80, 0));
    expect(values.last.hue, closeTo(90, 1));
  });
}
