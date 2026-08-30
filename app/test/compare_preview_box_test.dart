import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:phos_core/phos_core.dart';

import 'package:phos/preview/preview_service.dart';
import 'package:phos/widgets/compare_preview_box.dart';

Uint8List _smallJpeg() {
  final im = img.Image(width: 32, height: 24);
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      im.setPixelRgb(x, y, x * 8, 24, 255 - x * 8);
    }
  }
  return img.encodeJpg(im);
}

void main() {
  testWidgets('hold shows the original, release restores the style',
      (tester) async {
    final preview = PreviewService(
      render: ({
        required Uint8List baseJpeg,
        required Object params,
        required int width,
        required int version,
      }) async => baseJpeg,
      plainRender: ({required Uint8List baseJpeg, required int width}) async =>
          baseJpeg,
    );
    final jpeg = _smallJpeg();
    final events = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ComparePreviewBox(
              service: preview,
              baseJpeg: jpeg,
              params: const NikonParams(),
              width: 64,
              version: 1,
              onCompareChanged: events.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(events, isEmpty);
    expect(find.text('Original'), findsNothing);

    // Hold past the long-press timeout (500ms).
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ComparePreviewBox)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(events, [true]);
    expect(find.text('Original'), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(events, [true, false]);
    expect(find.text('Original'), findsNothing);
  });

  testWidgets('releasing without completing the hold never compares',
      (tester) async {
    final preview = PreviewService(
      render: ({
        required Uint8List baseJpeg,
        required Object params,
        required int width,
        required int version,
      }) async => baseJpeg,
      plainRender: ({required Uint8List baseJpeg, required int width}) async =>
          baseJpeg,
    );
    final events = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ComparePreviewBox(
              service: preview,
              baseJpeg: _smallJpeg(),
              params: const NikonParams(),
              width: 64,
              version: 1,
              onCompareChanged: events.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A quick tap: down and up before the long-press timeout.
    await tester.tap(find.byType(ComparePreviewBox));
    await tester.pumpAndSettle();

    expect(events, isEmpty);
    expect(find.text('Original'), findsNothing);
  });
}