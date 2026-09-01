import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phos/preview/preview_service.dart';
import 'package:phos/screens/style_detail_screen.dart';
import 'package:phos/state/app_model.dart';

void main() {
  testWidgets('style detail renders inside its unbounded-height ListView', (
    tester,
  ) async {
    // No real async I/O inside the fake-async zone: the model only performs
    // sync file checks against a directory that may not contain our files.
    final preview = PreviewService(
      render:
          ({
            required Uint8List baseJpeg,
            required Object params,
            required int width,
            required int version,
          }) async => baseJpeg,
      plainRender: ({required Uint8List baseJpeg, required int width}) async =>
          baseJpeg,
    );
    final model = AppModel(
      docDir: () async => Directory.systemTemp,
      preview: preview,
    );
    final recipe = model.builtins.first;

    await tester.pumpWidget(
      MaterialApp(
        home: StyleDetailScreen(model: model, recipe: recipe),
      ),
    );
    await tester.pumpAndSettle();

    // The original bug: StackFit.expand threw a layout exception inside the
    // unbounded-height ListView.
    expect(tester.takeException(), isNull);
    expect(find.text(recipe.name), findsOneWidget);

    // The 4:3 preview fills the 800x600 test surface; scroll to reach the
    // content below it.
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(
      find.text('Hold the preview to compare with the original'),
      findsOneWidget,
    );
    expect(find.text('Send to camera'), findsOneWidget);
    expect(find.text('Save .NP3 to device'), findsOneWidget);
  });

  testWidgets('swiping changes the active style', (tester) async {
    final preview = PreviewService(
      render:
          ({
            required Uint8List baseJpeg,
            required Object params,
            required int width,
            required int version,
          }) async => baseJpeg,
      plainRender: ({required Uint8List baseJpeg, required int width}) async =>
          baseJpeg,
    );
    final model = AppModel(
      docDir: () async => Directory.systemTemp,
      preview: preview,
    );
    final styles = model.builtins.take(2).toList();

    await tester.pumpWidget(
      MaterialApp(
        home: StyleDetailScreen(
          model: model,
          recipe: styles.first,
          styles: styles,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(styles.first.name), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text(styles[1].name), findsOneWidget);
  });
}
