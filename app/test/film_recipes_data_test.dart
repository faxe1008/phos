import 'package:flutter_test/flutter_test.dart';

import 'package:phos_core/phos_core.dart';
import 'package:phos/data/film_recipes_data.dart';

void main() {
  test('all bundled film.recipes sources parse cleanly', () {
    expect(filmRecipeSources, isNotEmpty);
    final names = <String>{};
    final ids = <String>{};
    for (final s in filmRecipeSources) {
      expect(s.name, isNotEmpty, reason: 'name for ${s.id}');
      expect(s.sourceUrl, startsWith('https://film.recipes/'));
      expect(ids.add(s.id), isTrue, reason: 'duplicate id ${s.id}');
      expect(names.add(s.name), isTrue, reason: 'duplicate name ${s.name}');

      final f = FujiRecipeParser.parse(s.settings);
      expect(f.filmSimulation, isNotNull,
          reason: 'missing film simulation in ${s.id}');
      expect(f.dynamicRange, isNotNull,
          reason: 'missing dynamic range in ${s.id}');

      final r = RecipeConverter.fromFujiText(s.settings, name: s.name);
      expect(r.mappingReport, isNotNull, reason: 'no report for ${s.id}');
      expect(r.nikon.baseProfileHint, isNotEmpty,
          reason: 'no base PC hint for ${s.id}');
    }
  });

  test('a bundled recipe end-to-end produces a parseable NP3', () {
    final s = filmRecipeSources
        .firstWhere((x) => x.id == 'kodak-gold-ii-classic-kodak-film-recipe');
    final r = RecipeConverter.fromFujiText(s.settings, name: s.name);
    expect(r.fuji!.dynamicRange, 'DR200');
    expect(r.whiteBalance?.tint, 9); // 4 - (-5)

    final p = Np3Codec.parse(RecipeConverter.toNp3(r));
    expect(p.name, 'Kodak Gold II');
  });
}