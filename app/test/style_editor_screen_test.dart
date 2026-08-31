import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phos_core/phos_core.dart';
import 'package:phos/preview/preview_service.dart';
import 'package:phos/screens/style_editor_screen.dart';
import 'package:phos/state/app_model.dart';

PreviewService _fakePreview() => PreviewService(
      render: ({
        required Uint8List baseJpeg,
        required Object params,
        required int width,
        required int version,
      }) async => baseJpeg,
      plainRender: ({
        required Uint8List baseJpeg,
        required int width,
      }) async => baseJpeg,
    );

void main() {
  testWidgets('editor saves slider changes to the recipe copy',
      (tester) async {
    // No real async I/O inside the fake-async zone.
    final model = AppModel(
        docDir: () async => Directory.systemTemp, preview: _fakePreview());
    final copy = model.duplicateForEditing(model.builtins.first);
    final before = copy.nikon.contrast;

    await tester.pumpWidget(
      MaterialApp(home: StyleEditorScreen(model: model, recipe: copy)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The 4:3 preview fills the test surface; scroll down so the lazy
    // ListView builds the sliders.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The first slider is Contrast.
    await tester.drag(find.byType(Slider).first, const Offset(80, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(copy.nikon.contrast, isNot(before));
    expect(model.imports, contains(copy));
    expect(model.imports.where((r) => r.id == copy.id), hasLength(1));
    expect(copy.id, startsWith('user:'));
  });

  testWidgets('neutral resets the sliders', (tester) async {
    final model = AppModel(
        docDir: () async => Directory.systemTemp, preview: _fakePreview());
    final source = UniversalRecipe(
      id: 'u-test-src',
      name: 'Contrasty',
      sourceFormat: SourceFormat.user,
      nikon: const NikonParams(contrast: 40),
    );
    final copy = model.duplicateForEditing(source);

    await tester.pumpWidget(
      MaterialApp(home: StyleEditorScreen(model: model, recipe: copy)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Neutral'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(copy.nikon.contrast, isNull);
  });
}