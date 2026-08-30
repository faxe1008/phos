import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phos/preview/preview_service.dart';
import 'package:phos/main.dart';
import 'package:phos/state/app_model.dart';
import 'package:phos/widgets/style_card.dart';

void main() {
  testWidgets('app boots and shows the catalog', (tester) async {
    // Synchronous identity renderer: no isolates in the test zone.
    final preview = PreviewService(render: ({
      required Uint8List baseJpeg,
      required Object params,
      required int width,
      required int version,
    }) async => baseJpeg);
    // No real async I/O inside the fake-async test zone: load() itself only
    // performs sync file reads against the injected directory.
    final model = AppModel(
        docDir: () async => Directory.systemTemp, preview: preview);

    await tester.pumpWidget(PhosApp(model: model));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Phos'), findsWidgets);
    expect(find.text('Catalog'), findsWidgets);
    expect(find.text('Clean Neutral'), findsOneWidget);
    expect(find.byType(StyleCard), findsWidgets);

    // SliverGrid only builds visible children; scroll to reach later cards.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Golden Hour'), findsOneWidget);
  });
}