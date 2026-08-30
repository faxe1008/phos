import '../model/colors.dart';
import '../model/nikon_params.dart';
import '../model/universal_recipe.dart';

/// The app's shipped catalog of styles.
///
/// Catalog styles are authored directly in Nikon terms (no conversion), so
/// they deploy 1:1 to the Z50II. They double as examples of what a fully
/// populated [NikonParams] looks like.
abstract final class BuiltinCatalog {
  static const List<CatalogEntry> styles = [
    CatalogEntry(
      id: 'clean-neutral',
      name: 'Clean Neutral',
      description: 'A balanced, minimal base: a touch of contrast, no color '
          'push. Good default for general shooting.',
      tags: ['neutral', 'everyday'],
      nikon: NikonParams(
        name: 'Clean Neutral',
        contrast: 5,
        highlights: -5,
        shadows: 5,
        saturation: 0,
        sharpening: 2,
        clarity: 0.5,
      ),
    ),
    CatalogEntry(
      id: 'warm-portrait',
      name: 'Warm Portrait',
      description: 'Soft warm midtones with gentle contrast and muted '
          'saturation for flattering skin tones.',
      tags: ['portrait', 'warm'],
      nikon: NikonParams(
        name: 'Warm Portrait',
        contrast: -10,
        highlights: -10,
        shadows: 10,
        saturation: -10,
        sharpening: 1,
        clarity: 0,
        colorGrading: {
          'midtones': GradingZone(hue: 35, chroma: 15),
        },
      ),
    ),
    CatalogEntry(
      id: 'punchy-landscape',
      name: 'Punchy Landscape',
      description: 'Crunchy contrast, lifted clarity and punchy greens for '
          'landscapes and travel.',
      tags: ['landscape', 'punchy'],
      nikon: NikonParams(
        name: 'Punchy Landscape',
        contrast: 25,
        highlights: -10,
        saturation: 15,
        sharpening: 3,
        clarity: 2,
        colorBlender: {
          'green': ColorChannel(chroma: 10),
        },
      ),
    ),
    CatalogEntry(
      id: 'golden-hour',
      name: 'Golden Hour',
      description: 'Amber highlights and warm mids to push a sunset feel into '
          'any scene.',
      tags: ['warm', 'creative'],
      nikon: NikonParams(
        name: 'Golden Hour',
        contrast: 10,
        shadows: 5,
        saturation: 10,
        colorGrading: {
          'highlights': GradingZone(hue: 40, chroma: 20),
          'midtones': GradingZone(hue: 35, chroma: 10),
        },
      ),
    ),
    CatalogEntry(
      id: 'classic-chrome',
      name: 'Classic Chrome-ish',
      description: 'Desaturated, slightly muted film look inspired by Fuji '
          'Classic Chrome. Pair with the Standard base PC.',
      tags: ['film', 'muted'],
      nikon: NikonParams(
        name: 'Classic Chrome-ish',
        contrast: 10,
        saturation: -30,
        sharpening: 2,
        clarity: 1,
        baseProfileHint: 'Standard',
      ),
    ),
    CatalogEntry(
      id: 'portra-ish',
      name: 'Portra-ish',
      description: 'Warm film emulation with lifted shadows and soft oranges, '
          'inspired by Kodak Portra 400.',
      tags: ['film', 'warm'],
      nikon: NikonParams(
        name: 'Portra-ish',
        contrast: -5,
        shadows: 15,
        saturation: -15,
        sharpening: 1,
        clarity: 0,
        colorBlender: {
          'orange': ColorChannel(chroma: 10),
        },
        colorGrading: {
          'midtones': GradingZone(hue: 35, chroma: 10),
        },
        baseProfileHint: 'Standard',
      ),
    ),
    CatalogEntry(
      id: 'noir-bw',
      name: 'Noir B&W',
      description: 'High-contrast monochrome with deep blacks. Set the base '
          'Picture Control to Monochrome on the camera.',
      tags: ['monochrome', 'high-contrast'],
      nikon: NikonParams(
        name: 'Noir B&W',
        contrast: 40,
        highlights: -20,
        shadows: -10,
        saturation: -100,
        sharpening: 3,
        clarity: 2,
        baseProfileHint: 'Monochrome',
      ),
    ),
    CatalogEntry(
      id: 'faded-lifted',
      name: 'Faded / Lifted Blacks',
      description: 'Lifted black point, soft contrast and muted color for a '
          'vintage faded look.',
      tags: ['vintage', 'faded'],
      nikon: NikonParams(
        name: 'Faded Blacks',
        contrast: -15,
        shadows: 10,
        blackLevel: 25,
        saturation: -20,
        sharpening: 1,
      ),
    ),
    CatalogEntry(
      id: 'moody-teal',
      name: 'Moody Teal',
      description: 'Teal shadows and amber highlights for a cinematic grade.',
      tags: ['cinematic', 'creative'],
      nikon: NikonParams(
        name: 'Moody Teal',
        contrast: 15,
        saturation: 5,
        colorGrading: {
          'shadows': GradingZone(hue: 190, chroma: 20),
          'highlights': GradingZone(hue: 40, chroma: 10),
        },
      ),
    ),
    CatalogEntry(
      id: 'high-key',
      name: 'High-Key Bright',
      description: 'Bright, airy look with lifted shadows and whites.',
      tags: ['bright', 'airy'],
      nikon: NikonParams(
        name: 'High-Key',
        contrast: -5,
        shadows: 30,
        whiteLevel: 20,
        blackLevel: 10,
        saturation: 5,
      ),
    ),
  ];

  static CatalogEntry? byId(String id) {
    for (final s in styles) {
      if (s.id == id) return s;
    }
    return null;
  }
}