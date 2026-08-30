import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:phos_core/phos_core.dart';
import 'package:phos/state/app_model.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('phos_model_test');
  });

  AppModel boot() => AppModel(docDir: () async => dir);

  test('builtins are exposed and imports empty at start', () {
    final m = boot();
    expect(m.builtins, isNotEmpty);
    expect(m.imports, isEmpty);
    expect(m.allStyles.length, m.builtins.length + m.discoveries.length);
  });

  test('discoveries are shipped fuji conversions with source links', () {
    final m = boot();
    expect(m.discoveries.length, 37);
    for (final s in m.discoveries) {
      expect(s.id, startsWith('filmrecipes:'));
      expect(s.sourceFormat, SourceFormat.fujiText);
      expect(s.sourceUrl, startsWith('https://film.recipes/'));
      expect(s.author, contains('Justin Gould'));
      expect(s.fuji, isNotNull);
      expect(s.mappingReport, isNotNull);
      expect(m.isShipped(s), isTrue);
    }
  });

  test('remove() is a no-op for discoveries', () {
    final m = boot();
    final before = m.discoveries.length;
    m.remove(m.discoveries.first);
    expect(m.discoveries.length, before);
  });

  test('discovery favorites behave like builtin favorites', () {
    final m = boot();
    final d = m.discoveries.first;
    expect(d.favorites, isFalse);
    m.toggleFavorite(d);
    expect(d.favorites, isTrue);
    expect(m.favorites, contains(d));
    m.toggleFavorite(d);
    expect(d.favorites, isFalse);
  });

  test('import names clash with discoveries too', () {
    final m = boot();
    final clash = UniversalRecipe(
      id: 'u-disc',
      name: m.discoveries.first.name,
      sourceFormat: SourceFormat.np3,
      nikon: NikonParams(),
    );
    expect(m.addRecipe(clash), isTrue);
    expect(m.imports.single.name, endsWith(' (2)'));
  });

  test('builtin styles carry nikon params and builtin source', () {
    final m = boot();
    for (final s in m.builtins) {
      expect(s.sourceFormat, SourceFormat.builtin);
      expect(s.nikon, isA<NikonParams>());
    }
  });

  test('remove() is a no-op for builtins', () {
    final m = boot();
    final before = m.builtins.length;
    m.remove(m.builtins.first);
    expect(m.builtins.length, before);
  });

  test('duplicate import by checksum is rejected, then succeeds after rename',
      () {
    final m = boot();
    final r1 = UniversalRecipe(
      id: 'u1',
      name: 'Test Import',
      sourceFormat: SourceFormat.xmp,
      nikon: NikonParams(contrast: 10),
      checksumSha256: 'abc123',
    );
    expect(m.addRecipe(r1), isTrue);
    expect(m.imports.length, 1);

    final r2 = UniversalRecipe(
      id: 'u2',
      name: 'Another Name',
      sourceFormat: SourceFormat.xmp,
      nikon: NikonParams(contrast: 10),
      checksumSha256: 'abc123',
    );
    expect(m.addRecipe(r2), isFalse);
    expect(m.imports.length, 1);

    final r3 = UniversalRecipe(
      id: 'u3',
      name: 'Different',
      sourceFormat: SourceFormat.fujiText,
      nikon: NikonParams(contrast: 10),
      checksumSha256: 'def456',
    );
    expect(m.addRecipe(r3), isTrue);
    expect(m.imports.length, 2);
  });

  test('clashing display names get a counter suffix', () {
    final m = boot();
    final clash = UniversalRecipe(
      id: 'u4',
      name: m.builtins.first.name,
      sourceFormat: SourceFormat.np3,
      nikon: NikonParams(),
    );
    expect(m.addRecipe(clash), isTrue);
    expect(m.imports.single.name, endsWith(' (2)'));
  });

  test('toggleFavorite flips the flag for imports and builtins', () {
    final m = boot();
    expect(m.favorites, isEmpty);

    final r = UniversalRecipe(
      id: 'u6',
      name: 'Fav Test',
      sourceFormat: SourceFormat.xmp,
      nikon: NikonParams(),
    );
    m.addRecipe(r);
    m.toggleFavorite(r);
    expect(r.favorites, isTrue);
    expect(m.favorites.single.name, 'Fav Test');

    final b = m.builtins.first;
    m.toggleFavorite(b);
    expect(b.favorites, isTrue);
    expect(m.favorites.length, 2);

    m.toggleFavorite(b);
    expect(b.favorites, isFalse);
    expect(m.favorites.length, 1);
  });

  test('remove() drops imports', () {
    final m = boot();
    final r = UniversalRecipe(
      id: 'u5',
      name: 'Temp',
      sourceFormat: SourceFormat.xmp,
      nikon: NikonParams(),
    );
    m.addRecipe(r);
    final id = m.imports.single.id;
    m.remove(m.imports.single);
    expect(m.imports.any((s) => s.id == id), isFalse);
  });
}