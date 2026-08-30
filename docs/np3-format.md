# NP3 / NCP binary format (Z50II, firmware-era 2.0)

Reverse-engineered and verified against the single-variable golden samples in
[sssota/nikon-flexible-color-picture-control](https://github.com/sssota/nikon-flexible-color-picture-control)
(MIT). All multi-byte values are **big-endian**.

## File layout

```
0x00  4 bytes   magic  4E 43 50 00  ("NCP\0")
0x04  4 bytes   version  u32 = 256 (0x100)
0x08  4 bytes   fmt_len  u32 = 4
0x0C  4 bytes   fmt_str  "0310"
0x10  ...       TLV entries
              [optional comment entry]
              [optional tone-curve entry]
              4 bytes  trailer  00 00 00 00
```

Each TLV entry: `tag u32` + `len u32` + `len` bytes of value.
The **tag id** used below is `tag >> 8` (entry tags are `id << 8`).

## Base entries (31 total, tag ids 2..32)

A base file with no extensions is exactly 388 bytes of header+entries.
Offsets are absolute file offsets in that base layout.

| Offset | tag id | Field | Encoding |
|--------|--------|-------|----------|
| 0x18 | 2 | Name | 20 bytes, Latin-1, NUL-padded |
| 0x3C | 12..19 | (unconfirmed) | preserved |
| 0x52 | 6 | Sharpening | quarter step: `(b - 0x80) / 4`, range -3..+9 (default 2.0) |
| 0x5C | 7 | Clarity | quarter step, -5..+5 (default 0.5) |
| 0xF2 | 22 | Mid-range sharpening | quarter step, -5..+5 (default 1.0) |
| 0x110 | 25 | Contrast | `b - 0x80`, -100..+100 |
| 0x11A | 26 | Highlights | `b - 0x80` |
| 0x124 | 27 | Shadows | `b - 0x80` |
| 0x12E | 28 | White level | `b - 0x80` |
| 0x138 | 29 | Black level | `b - 0x80` |
| 0x142 | 30 | Saturation | `b - 0x80` |
| 0x14C | 31 | Color blender | 8 channels × 3 bytes (hue, chroma, brightness, each `b-0x80`), + 4 unconfirmed bytes (`01 01 01 00`) |
| 0x170 | 32 | Color grading | 3 zones × 4 bytes, then blending + balance (below) |

Channel order (blender): red, orange, yellow, green, cyan, blue, purple,
magenta. Zone order (grading): highlights, midtones, shadows.

### Color grading details (entry at 0x170, 20 bytes)

Per zone (4 bytes):
- hue: 12-bit, `b0 = 0x80 | (hue >> 8) & 0x0f`, `b1 = hue & 0xff` (0..4095)
- chroma: `b2 - 0x80` (-100..+100)
- brightness: `b3 - 0x80` (-100..+100)

Then:
- 4 unconfirmed bytes (observed `01 01 01 00`) — preserved
- blending: `b - 0x80`, 0..100, default 50
- 1 unconfirmed byte (`01`)
- balance: `b - 0x80`, -100..+100, default 0
- 1 unconfirmed byte (`01`)

## Tone-curve extension (tag 0x00000002, 578-byte payload)

Present only when the file uses a custom curve. When present, the five
tonal-slider entries (tag ids 25..29) are replaced by the **sentinel**
`01 01` (both bytes) — the camera ignores the slider values.

```
0x00  8 bytes   constant header  49 30 00 FF 00 FF 01 00
0x08  1 byte    point count N (2..20), includes the 2 anchors
0x09  2 bytes   reserved 00 00
0x0B  40 bytes  N (x, y) uint8 pairs, rest zero-filled.
                The last two points are always the white anchor (255,255)
                followed by the black anchor (0,0).
0x33  15 bytes  reserved zeros
0x42  512 bytes 256 × uint16 BE LUT
```

LUT semantics: `lut[i]` is the 0..32767 output for 8-bit input `i + 1`
(input 0 is implicitly 0).

The **identity** LUT the camera writes for a neutral curve is
`round((i + 1) * 32767 / 256)` (half-up rounding — verified against
`tonecurve-noop.NP3`; a floor-division LUT differs in 128 entries by 1).

## Comment extension (tag 0x00010100)

UTF-8 text, NUL-terminated, payload length even (padded with one extra NUL
when odd). Max ~280 characters observed (584-byte payload).

## Generation strategy (Phos)

- Embed the 388-byte base layout of a known-good neutral file
  (`kVanillaTemplate`) and patch only the confirmed offsets above.
- Unconfirmed bytes are inherited from the template, never invented.
- Unspecified parameters get the flexible-color base defaults:
  sharpening 2.0, clarity 0.5, mid-range 1.0, tones 0, saturation 0,
  grading blending 50, balance 0.
- Identity tone curves are canonicalized away (no sentinel, no chunk).
- The 4-byte zero trailer is appended last, after any extension entries.

## Known gaps

- Entry tag ids 3..5 and 8..11, 20..21, 23..24 (offsets 0x3C..0x50,
  0x7C..0xBC, 0xEC..0xF0, 0x100..0x10C) are not decoded; they are copied
  through from the template. Confirm their meaning before exposing them.
- The 4 unconfirmed bytes in the blender entry and 3 unconfirmed bytes in
  the grading entry are preserved as-is.
- Per-camera quirks (other than the Z50II) are untested.