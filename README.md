# Phos

Camera recipes for Nikon Z cameras — build, import, and deploy look
("Picture Control") files from any source format.

Phos speaks a vendor-neutral recipe language. You can bring a Lightroom
preset (.xmp), a Fujifilm film recipe, or an existing Nikon NP3, and Phos
"breaks it down" into the closest thing a Z-body can natively apply — a
Picture Control (.NP3/.NCP) — with a per-field fidelity report that never
pretends a lossy conversion is exact.

Status: **core complete, mobile app functional.** The `core/` package is
the tested foundation; the Flutter app (`app/`) gives it a home on your
phone: a browsable style library with live previews, import, favorites,
and one-tap `.NP3` export for the camera.

## Repository layout

```
core/    phos_core — pure-Dart, no platform dependencies
  lib/src/model/     UniversalRecipe, NikonParams, XmpMeta, FujiMeta, report
  lib/src/np3/       .NP3/.NCP parser + generator (template-patch strategy)
  lib/src/xmp/       Lightroom XMP sidecar parser + generator
  lib/src/fuji/      Fujifilm recipe text parser (fujixweekly + film.recipes)
  lib/src/mapping/   fidelity-reporting conversions (XMP→NP3, Fuji→NP3)
  lib/src/catalog/   shipped style catalog
  test/              87 tests + golden fixtures (ssssota NP3 samples, MIT)
app/     Flutter app (Android + iOS)
  lib/state/         AppModel — library, favorites, persistence, import
  lib/preview/       NikonPreviewFilter + isolate-based PreviewService
  lib/import/        file sniffing (NP3 / XMP / Fuji text)
  lib/data/          bundled film.recipes signature recipes (generated)
  lib/screens/       library grid, style detail with fidelity report
  lib/widgets/       preview cards, status chips, report rows
  test/              23 tests (filter math, model, data, widget smoke)
tool/    fetch_film_recipes.py — regenerates app/lib/data/film_recipes_data.dart
data/    Nikon Remote Module SDK 2.0.0 (reference for the camera link)
docs/    format notes and mapping tables
.github/ CI: analyze + test (core & app) + debug APK artifact
```

## Quick start (core)

```sh
cd core
dart pub get
dart analyze
dart test
```

```dart
import 'package:phos_core/phos_core.dart';

// Import a Lightroom preset, convert, deploy.
final bytes = File('preset.xmp').readAsBytesSync();
final recipe = RecipeConverter.fromXmp(bytes);
print(recipe.mappingReport.summary); // e.g. "APPROXIMATION: 9 mapped, 3 unsupported, ..."
final np3 = RecipeConverter.toNp3(recipe); // write to the camera

// Or start from the shipped catalog.
final style = BuiltinCatalog.byId('portra-ish')!;
```

## Quick start (app)

Prereqs: [Flutter](https://flutter.dev) (3.47.1+), Android SDK.

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
# → build/app/outputs/flutter-apk/app-debug.apk
```

Install on your phone (`adb install app-debug.apk` or transfer the file).
A debug build is fine for on-device use; CI also publishes the debug APK
as a workflow artifact.

### Using the app

1. **Preview base.** Out of the box every style is previewed on a generated
   test card. Tap the banner (or the image icon) to pick your own photo —
   previews are rendered the way the parameters change it (tone, saturation,
   color tinting, split-toning, sharpening), as a close approximation of
   in-camera processing.
2. **Browse the library.** Catalog styles ship with the app, as do the
   "From film.recipes" signature looks (converted Fuji recipes by
   Justin Gould — the detail screen links each one to its original post).
   Imported styles live in "My imports". Star styles to pin them to
   "Favorites". To refresh the bundled film.recipes list, run
   `python3 tool/fetch_film_recipes.py` from the repo root.
3. **Import.** "Import style" accepts Lightroom `.xmp` presets, Fujifilm
   film-recipe text, and existing `.NP3`/`.NCP` files (content-sniffed,
   not trusted by extension). Duplicates by source checksum are rejected.
4. **Check fidelity.** The detail screen shows the per-field mapping
   report — exactly which parameters transferred, which were scaled,
   clamped, or left unsupported.
5. **Deploy.** "Save .NP3 to device" writes a ready-to-load Picture
   Control. Copy it to your camera's SD card `CustomLUT/` folder, then on
   the camera: Menu → Setup → Custom LUT → select the file.

## Design principles

- **Never lie about fidelity.** Every converted field carries a status:
  `exact`, `scaled`, `approximated`, `clamped`, `unsupported`,
  `superseded`, or `ignored`. The UI shows exactly what was lost.
- **No invented bytes.** The NP3 generator patches confirmed offsets of a
  known-good base template; unconfirmed bytes are preserved, never guessed.
- **Versioned mapping formulas** (`xmp->np3:1`, `fuji->np3:1`) so old
  recipes re-convert deterministically when formulas improve.
- **Provenance.** Every recipe stores its source format, the SHA-256 of
  the original artifact, and — when it comes from a public page — the
  source URL for attribution.

## License

MIT (see [LICENSE](LICENSE)). NP3 test fixtures are from
[sssota/nikon-flexible-color-picture-control](https://github.com/sssota/nikon-flexible-color-picture-control)
(MIT) — see `core/test/fixtures/np3/ATTRIBUTION.md`.

The "From film.recipes" styles are parameter values taken from the free
public recipes of [film.recipes](https://film.recipes) (Justin Gould). The
numeric settings are facts, not creative content; each bundled entry keeps
a link to its original post, and the app credits the author in the UI.