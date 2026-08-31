import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phos_core/phos_core.dart';
import 'package:phos/preview/preview_service.dart';
import 'package:phos/screens/style_editor_screen.dart';
import 'package:phos/state/app_model.dart';

PreviewService _fakePreview() => PreviewService(
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

void main() {
  testWidgets('editor saves slider changes to the recipe copy', (tester) async {
    // No real async I/O inside the fake-async zone.
    final model = AppModel(
      docDir: () async => Directory.systemTemp,
      preview: _fakePreview(),
    );
    final copy = model.duplicateForEditing(model.builtins.first);
    final before = copy.nikon.contrast;

    await tester.pumpWidget(
      MaterialApp(
        home: StyleEditorScreen(model: model, recipe: copy),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Scroll the lazy ListView until the Contrast slider's label is visible,
    // then drag that specific slider (the page has many sliders).
    await tester.scrollUntilVisible(
      find.text('Contrast'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(sliderForLabel('Contrast'), const Offset(80, 0));
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
      docDir: () async => Directory.systemTemp,
      preview: _fakePreview(),
    );
    final source = UniversalRecipe(
      id: 'u-test-src',
      name: 'Contrasty',
      sourceFormat: SourceFormat.user,
      nikon: const NikonParams(contrast: 40),
    );
    final copy = model.duplicateForEditing(source);

    await tester.pumpWidget(
      MaterialApp(
        home: StyleEditorScreen(model: model, recipe: copy),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Neutral'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(copy.nikon.contrast, isNull);
  });

  testWidgets('color grading: hue and blending sliders update the copy', (
    tester,
  ) async {
    final model = AppModel(
      docDir: () async => Directory.systemTemp,
      preview: _fakePreview(),
    );
    final copy = model.duplicateForEditing(model.builtins.first);

    await tester.pumpWidget(
      MaterialApp(
        home: StyleEditorScreen(model: model, recipe: copy),
      ),
    );
    await tester.pumpAndSettle();

    // 'Midtones' is unique (only the grading section uses it); the
    // highlights Hue slider sits just above it.
    await tester.scrollUntilVisible(
      find.text('Midtones'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(sliderForLabel('Hue'), const Offset(80, 0));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Blending'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(sliderForLabel('Blending'), const Offset(60, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final highlights = copy.nikon.colorGrading!['highlights']!;
    expect(highlights.hue, greaterThan(0));
    expect(copy.nikon.gradingBlending, greaterThan(50));
  });
}

/// The [Slider] that belongs to the row labelled [label] (the editor's
/// rows are Row(label, value) + Slider inside one Column).
Finder sliderForLabel(String label) => find
    .descendant(
      of: find
          .ancestor(of: find.text(label).first, matching: find.byType(Column))
          .first,
      matching: find.byType(Slider),
    )
    .first;
