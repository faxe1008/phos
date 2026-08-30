import 'dart:convert';
import 'dart:io';

import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

void main() {
  test('fromXmp: full pipeline to a parseable NP3', () {
    final bytes = File('test/fixtures/xmp/basic-pv2.xmp').readAsBytesSync();
    final recipe = RecipeConverter.fromXmp(bytes);

    expect(recipe.sourceFormat, SourceFormat.xmp);
    expect(recipe.name, 'Everyday Balanced');
    expect(recipe.checksumSha256, isNotEmpty);
    expect(recipe.xmp, isNotNull);
    expect(recipe.whiteBalance!.temperature, 5450);
    expect(recipe.nikon.contrast, 20);
    expect(recipe.mappingReport, isNotNull);

    final np3 = RecipeConverter.toNp3(recipe);
    final p = Np3Codec.parse(np3);
    expect(p.name, 'Everyday Balanced');
    expect(p.contrast, 20);
    expect(p.highlights, -20);
    expect(p.saturation, -8);
  });

  test('fromXmp: re-exported XMP preserves parsed fields', () {
    final bytes = File('test/fixtures/xmp/basic-pv2.xmp').readAsBytesSync();
    final recipe = RecipeConverter.fromXmp(bytes);
    final out = RecipeConverter.toXmp(recipe);
    final m2 = XmpParser.parse(out);
    expect(m2.contrast, recipe.xmp!.contrast);
    expect(m2.whiteBalance!.temperature, recipe.xmp!.whiteBalance!.temperature);
  });

  test('fromFujiText: pipeline to a parseable NP3', () {
    final text =
        File('test/fixtures/fuji/classic_chrome.txt').readAsStringSync();
    final recipe = RecipeConverter.fromFujiText(text);

    expect(recipe.sourceFormat, SourceFormat.fujiText);
    expect(recipe.name, 'Classic Chrome');
    expect(recipe.fuji, isNotNull);
    expect(recipe.whiteBalance!.tint, 7); // 2 - (-5)

    final np3 = RecipeConverter.toNp3(recipe);
    final p = Np3Codec.parse(np3);
    expect(p.name, 'Classic Chrome');
    expect(p.saturation, 50);
  });

  test('fromNp3: imported NP3 keeps its parameters', () {
    final bytes = File('test/fixtures/np3/vanilla.NP3').readAsBytesSync();
    final recipe = RecipeConverter.fromNp3(bytes);
    expect(recipe.sourceFormat, SourceFormat.np3);
    expect(recipe.nikon, isNotNull);
    // round-trip back to bytes
    final out = RecipeConverter.toNp3(recipe);
    expect(Np3Codec.parse(out).name, recipe.nikon.name);
  });

  test('checksum is a stable sha256 of the source bytes', () {
    // Known vector: sha256("abc").
    expect(RecipeConverter.sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    final r1 = RecipeConverter.fromFujiText('');
    final r2 = RecipeConverter.fromFujiText('');
    expect(r1.checksumSha256, r2.checksumSha256);
    expect(r1.checksumSha256, isNotEmpty);
  });

  test('sourceUrl survives a JSON round trip and copyWith', () {
    final r = UniversalRecipe(
      id: 'u1',
      name: 'Linked',
      sourceFormat: SourceFormat.fujiText,
      sourceUrl: 'https://film.recipes/example-recipe/',
    );
    final back = UniversalRecipe.fromJson(r.toJson());
    expect(back.sourceUrl, 'https://film.recipes/example-recipe/');
    expect(r.copyWith(sourceUrl: 'https://example.com/').sourceUrl,
        'https://example.com/');
    expect(UniversalRecipe.fromJson(r.toJson()).sourceUrl,
        'https://film.recipes/example-recipe/');
  });

  test('catalog styles all generate valid NP3', () {
    for (final style in BuiltinCatalog.styles) {
      final np3 = Np3Codec.generate(style.nikon);
      final p = Np3Codec.parse(np3);
      expect(p.name, Np3Codec.sanitizeNp3Name(style.nikon.name ?? style.name),
          reason: 'style ${style.id} name');
    }
    expect(BuiltinCatalog.byId('noir-bw'), isNotNull);
    expect(BuiltinCatalog.styles.length, greaterThanOrEqualTo(8));
  });
}