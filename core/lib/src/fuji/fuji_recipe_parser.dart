import '../model/fuji_meta.dart';

/// Parses Fujifilm film-simulation "recipes" in the popular fujixweekly.com
/// text layout, e.g.:
///
/// ```
/// Classic Chrome
/// Dynamic Range: DR400
/// Highlight: -2
/// Shadow: +1
/// Color: -2
/// Noise Reduction: 0
/// Sharpness: 0
/// Clarity: +1
/// Grain Effect: Strong, Fine
/// Color Chrome Effect: Off
/// Color Chrome Effect Blue: Weak
/// White Balance: Daylight 2 Red 1 Blue
/// ISO: 400
/// Exposure Compensation: +1/3
/// ```
class FujiRecipeParser {
  static const Map<String, String> _keyAliases = {
    'film simulation': 'filmSimulation',
    'simulation': 'filmSimulation',
    'film': 'filmSimulation',
    'dynamic range': 'dynamicRange',
    'dr': 'dynamicRange',
    'highlight': 'highlightTone',
    'highlights': 'highlightTone',
    'highlight tone': 'highlightTone',
    'highlight tone adjustment': 'highlightTone',
    'shadow': 'shadowTone',
    'shadows': 'shadowTone',
    'shadow tone': 'shadowTone',
    'shadow tone adjustment': 'shadowTone',
    'color': 'color',
    'colour': 'color',
    'saturation': 'color',
    'noise reduction': 'noiseReduction',
    'nr': 'noiseReduction',
    'iso n.r.': 'noiseReduction',
    'iso noise reduction': 'noiseReduction',
    'sharpness': 'sharpness',
    'sharpening': 'sharpness',
    'clarity': 'clarity',
    'grain effect': 'grain',
    'grain': 'grain',
    'color chrome effect': 'colorChrome',
    'color chrome': 'colorChrome',
    'colour chrome effect': 'colorChrome',
    'col. chr. effect': 'colorChrome',
    'color chrome effect blue': 'colorChromeBlue',
    'colour chrome effect blue': 'colorChromeBlue',
    'col. chr. blue': 'colorChromeBlue',
    'white balance': 'whiteBalance',
    'wb': 'whiteBalance',
    'iso': 'iso',
    'exposure compensation': 'exposureComp',
    'exposure': 'exposureComp',
    'ev comp.': 'exposureComp',
  };

  static FujiMeta parse(String text) {
    // Normalize typographic minus/hyphen variants (film.recipes and many
    // blog posts use U+2011 non-breaking hyphen and U+2212 minus sign).
    text = text
        .replaceAll('\u2011', '-')
        .replaceAll('\u2212', '-')
        .replaceAll('\u2013', '-');

    String? film;
    String? dr;
    double? highlight, shadow, color, noise, sharpness, clarity;
    String? grainStrength, grainSize, chrome, chromeBlue, wbMode, iso, exp;
    int? wbRed, wbBlue;

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final ci = line.indexOf(':');
      if (ci < 0) {
        // A bare first line is the film simulation.
        film ??= line;
        continue;
      }
      final key = line.substring(0, ci).trim().toLowerCase();
      final value = line.substring(ci + 1).trim();
      final field = _keyAliases[key];
      if (field == null || value.isEmpty) continue;

      switch (field) {
        case 'filmSimulation':
          film ??= value;
        case 'dynamicRange':
          dr = value.toUpperCase().replaceAll(' ', '');
        case 'highlightTone':
          highlight = _num(value);
        case 'shadowTone':
          shadow = _num(value);
        case 'color':
          color = _num(value);
        case 'noiseReduction':
          noise = _num(value);
        case 'sharpness':
          sharpness = _num(value);
        case 'clarity':
          clarity = _num(value);
        case 'grain':
          final parts = value.split(',').map((p) => p.trim()).toList();
          grainStrength = parts[0].isEmpty ? 'Off' : parts[0];
          if (parts.length > 1) grainSize = parts[1];
        case 'colorChrome':
          chrome = value;
        case 'colorChromeBlue':
          chromeBlue = value;
        case 'whiteBalance':
          final base = RegExp(r'^[^0-9]*').firstMatch(value)!.group(0)!;
          var end = base.length;
          while (end > 0 &&
              (base[end - 1] == ',' || base[end - 1] == ' ' || base[end - 1] == '+')) {
            end--;
          }
          final mode = base.substring(0, end).trim();
          wbMode = mode.isEmpty ? null : mode;
          final red = RegExp(r'([+-]?\d+(?:\.\d+)?)\s*red', caseSensitive: false);
          final blue = RegExp(r'([+-]?\d+(?:\.\d+)?)\s*blue', caseSensitive: false);
          final rm = red.firstMatch(value);
          final bm = blue.firstMatch(value);
          if (rm != null) wbRed = _numInt(rm.group(1));
          if (bm != null) wbBlue = _numInt(bm.group(1));
        case 'iso':
          iso = value;
        case 'exposureComp':
          exp = value;
      }
    }

    return FujiMeta(
      filmSimulation: film,
      dynamicRange: dr,
      highlightTone: highlight,
      shadowTone: shadow,
      color: color,
      noiseReduction: noise,
      sharpness: sharpness,
      clarity: clarity,
      grainStrength: grainStrength,
      grainSize: grainSize,
      colorChromeEffect: chrome,
      colorChromeEffectBlue: chromeBlue,
      whiteBalanceMode: wbMode,
      wbRedShift: wbRed,
      wbBlueShift: wbBlue,
      iso: iso,
      exposureComp: exp,
    );
  }

  static double? _num(String s) => double.tryParse(s.trim());

  static int? _numInt(String? s) => s == null ? null : int.tryParse(s.trim());
}