# Mapping tables

How Phos converts other-world recipe formats into the Nikon projection
(`NikonParams`), and what each fidelity status means. Formulas are versioned
(`xmp->np3:1`, `fuji->np3:1`); bump the version when a formula changes so
stored recipes can be re-converted deterministically.

## Statuses

| Status | Meaning |
|--------|---------|
| `exact` | Same semantics, same range; copied 1:1 |
| `scaled` | Same semantics, range rescaled to the target |
| `approximated` | Semantics only roughly overlap; best effort |
| `clamped` | Mapped, but the source value was clamped to the target range |
| `unsupported` | No target equivalent; kept in source metadata only |
| `superseded` | Overridden by a higher-priority source field |
| `ignored` | Source field was already at its default; nothing to do |

## XMP (Lightroom) → NP3 — `xmp->np3:1`

| Source | Target | Formula | Status |
|--------|--------|---------|--------|
| `Contrast2012` (pv≥2) | `tone.contrast` | ×(100/150) | scaled |
| `Contrast` (pv<2) | `tone.contrast` | ×2 | scaled |
| `Highlights2012` / `Shadows2012` / `Whites2012` / `Blacks2012` | highlights / shadows / whiteLevel / blackLevel | 1:1 (clamp ±100) | exact / clamped |
| `Saturation` | `tone.saturation` | 1:1 | exact |
| `Vibrance` | `tone.saturation` | +50% of value folded in | approximated |
| `Clarity2012` | `detail.clarity` | ÷20 → -5..+5 | scaled |
| `SharpenDetail` | `detail.sharpening` | ×(9/100) → 0..9 | scaled |
| `Sharpening` (legacy) | `detail.sharpening` | ≥0: ×(9/300); <0: ×(3/300) | approximated |
| `ToneCurvePV2012` | `tone.toneCurve` | point curve → interpolated 256-entry LUT | approximated |
| `Parametric*` (only if no master curve) | `tone.toneCurve` | ±128 LUT units at shadow/highlight end, linear taper | approximated |
| `HSL <ch> Hue` | `color.colorBlender.<ch>.hue` | ×(100/180) | scaled |
| `HSL <ch> Saturation` | `color.colorBlender.<ch>.chroma` | 1:1 | exact |
| `HSL <ch> Luminance` | `color.colorBlender.<ch>.brightness` | 1:1 | exact |
| `ColorGrade<Zone>Hue` | `color.colorGrading.<zone>.hue` | 1:1 (0..360) | exact |
| `ColorGrade<Zone>Sat` | `color.colorGrading.<zone>.chroma` | (v−50)×2 | scaled |
| `ColorGrade<Zone>Lum` | `color.colorGrading.<zone>.brightness` | 1:1 | exact |
| `SplitToning<Zone>Hue/Sat` (legacy) | `color.colorGrading.<zone>` | hue 1:1, sat 1:1 | approximated |
| `ShadowTint` | `color.colorGrading.shadows` | hue 120/300 (green/magenta), chroma \|v\|/2 | approximated |

Precedence: a non-identity master curve **supersedes** the tonal sliders
(they are nulled in the output and reported as `superseded`), matching the
NP3 sentinel behavior on the camera.

Unsupported (kept in metadata): `Exposure`, `WhiteBalance`/`Temp`/`Tint`,
`Texture`, `Dehaze`, `SharpenRadius`, `SharpenEdgeMasking`, per-channel
RGB curves, `Grain*`, `PostCropVignette*`, `ColorGradeGlobalSat`.

## Fujifilm recipe → NP3 — `fuji->np3:1`

| Source | Target | Formula | Status |
|--------|--------|---------|--------|
| `Color` | `tone.saturation` | ×25 → -100..+100 | scaled |
| `Sharpness` | `detail.sharpening` | ≥0: ×(9/4); <0: ×(3/4) — Nikon's range is asymmetric | approximated |
| `Clarity` | `detail.clarity` | 1:1 (-5..+5) | exact |
| `Highlight` + DR bias | `tone.highlights` | (v + bias) ×(100/4); bias: DR200 −0.5, DR400 −1.0 | scaled |
| `Shadow` | `tone.shadows` | ×(100/4) | scaled |
| `Color Chrome Effect` | colorBlender red/orange chroma | weak: +10/+5, strong: +20/+10 | approximated |
| `Color Chrome Effect Blue` | colorBlender blue/cyan | weak: +10/+5 (blue brightness −5), strong: +20/+10 (−10) | approximated |
| WB `+R / −B` shift | `color.colorGrading.midtones` | warmth=(R−B)/2; hue 35 (warm) / 205 (cool); chroma min(40, \|warmth\|×3) | approximated |
| film simulation | `baseProfileHint` | Velvia/Provia/Vivid→Vivid; Eterna/Cinema/Pro Neg/Reala/Astia→Neutral; Monochrome→Monochrome; else Standard | note |

Unsupported (camera settings, kept in metadata): grain effect, noise
reduction, ISO, exposure compensation, WB mode, film simulation (as an
NP3 field — it only informs the base-Picture-Control hint).

## What NP3 cannot express (any source)

- White balance, exposure, ISO
- Grain, vignette, dehaze, texture
- Per-channel (RGB) tone curves
- Vibrance (folded into saturation at 50%)
- Local adjustments, masks, AI selections

These live on in `UniversalRecipe`'s source metadata so a future
export-to-post path can use them.