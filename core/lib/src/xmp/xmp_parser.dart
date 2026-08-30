import 'dart:convert';

import 'package:xml/xml.dart';

import '../model/xmp_meta.dart';

/// Parses Lightroom/XMP Develop preset sidecars into [XmpMeta].
///
/// Handles both the classic attribute-form (`crs:Exposure2012="0.5"` on an
/// `rdf:Description`) and the `CR:` prefix used by newer properties, and
/// merges attributes spread across multiple `rdf:Description` elements.
class XmpParser {
  static const Map<String, _Prop> _props = {
    'ProcessVersion': _Prop.d('processVersion'),
    'WhiteBalance': _Prop.wbMode(),
    'Temp': _Prop.d('temperature'),
    'Tint': _Prop.d('tint'),
    'Exposure2012': _Prop.d('exposure'),
    'Exposure': _Prop.d('exposure'),
    'Contrast2012': _Prop.d('contrast'),
    'Contrast': _Prop.d('contrast'),
    'Highlights2012': _Prop.d('highlights'),
    'Highlights': _Prop.d('highlights'),
    'Shadows2012': _Prop.d('shadows'),
    'Shadows': _Prop.d('shadows'),
    'Whites2012': _Prop.d('whites'),
    'Whites': _Prop.d('whites'),
    'Blacks2012': _Prop.d('blacks'),
    'Blacks': _Prop.d('blacks'),
    'Vibrance': _Prop.d('vibrance'),
    'Saturation': _Prop.d('saturation'),
    'Clarity2012': _Prop.d('clarity'),
    'Clarity': _Prop.d('clarity'),
    'Texture': _Prop.d('texture'),
    'Dehaze': _Prop.d('dehaze'),
    'ShadowTint': _Prop.d('shadowTint'),
    'ToneCurvePV2012': _Prop.s('toneCurve'),
    'ToneCurvePV2012Red': _Prop.s('toneCurveRed'),
    'ToneCurvePV2012Green': _Prop.s('toneCurveGreen'),
    'ToneCurvePV2012Blue': _Prop.s('toneCurveBlue'),
    'ParametricShadows': _Prop.d('parametricShadows'),
    'ParametricDarks': _Prop.d('parametricDarks'),
    'ParametricLights': _Prop.d('parametricLights'),
    'ParametricHighlights': _Prop.d('parametricHighlights'),
    'SplitToningShadowHue': _Prop.d('splitToningShadowHue'),
    'SplitToningShadowSaturation': _Prop.d('splitToningShadowSaturation'),
    'SplitToningHighlightHue': _Prop.d('splitToningHighlightHue'),
    'SplitToningHighlightSaturation': _Prop.d('splitToningHighlightSaturation'),
    'SplitToningBalance': _Prop.d('splitToningBalance'),
    'SplitShadowHue': _Prop.d('splitToningShadowHue'),
    'SplitShadowSaturation': _Prop.d('splitToningShadowSaturation'),
    'SplitHighlightHue': _Prop.d('splitToningHighlightHue'),
    'SplitHighlightSaturation': _Prop.d('splitToningHighlightSaturation'),
    'SplitBalance': _Prop.d('splitToningBalance'),
    'SharpenDetail': _Prop.d('sharpenDetail'),
    'SharpenRadius': _Prop.d('sharpenRadius'),
    'SharpenEdgeMasking': _Prop.d('sharpenEdgeMasking'),
    'Sharpening': _Prop.d('sharpening'),
    'GrainAmount': _Prop.d('grainAmount'),
    'GrainSize': _Prop.d('grainSize'),
    'GrainRoughness': _Prop.d('grainRoughness'),
    'PostCropVignetteAmount': _Prop.d('vignetteAmount'),
    'PostCropVignetteMidpoint': _Prop.d('vignetteMidpoint'),
    'PostCropVignetteRoundness': _Prop.d('vignetteRoundness'),
    'PostCropVignetteFeather': _Prop.d('vignetteFeather'),
    'ColorGradeMidtoneHue': _Prop.cg('mid', 'hue'),
    'ColorGradeMidtoneSat': _Prop.cg('mid', 'saturation'),
    'ColorGradeMidtoneLum': _Prop.cg('mid', 'luminance'),
    'ColorGradeShadowHue': _Prop.cg('shadow', 'hue'),
    'ColorGradeShadowSat': _Prop.cg('shadow', 'saturation'),
    'ColorGradeShadowLum': _Prop.cg('shadow', 'luminance'),
    'ColorGradeHighlightHue': _Prop.cg('high', 'hue'),
    'ColorGradeHighlightSat': _Prop.cg('high', 'saturation'),
    'ColorGradeHighlightLum': _Prop.cg('high', 'luminance'),
    'ColorGradeBalance': _Prop.d('colorGradeBalance'),
    'ColorGradeBlending': _Prop.d('colorGradeBlending'),
    'ColorGradeGlobalSat': _Prop.d('colorGradeGlobalSaturation'),
    'Name': _Prop.s('name'),
    'description': _Prop.s('description'),
    'rights': _Prop.s('copyright'),
    'creator': _Prop.s('author'),
    'CreatorTool': _Prop.s('author'),
  };

  /// HSL attribute suffixes per Lightroom channel.
  static const Map<XmpHslColor, String> _hslChannels = {
    XmpHslColor.red: 'Red',
    XmpHslColor.orange: 'Orange',
    XmpHslColor.yellow: 'Yellow',
    XmpHslColor.green: 'Green',
    XmpHslColor.aqua: 'Aqua',
    XmpHslColor.blue: 'Blue',
    XmpHslColor.purple: 'Purple',
    XmpHslColor.magenta: 'Magenta',
  };

  static XmpMeta parse(List<int> bytes) =>
      parseString(utf8.decode(bytes, allowMalformed: true));

  static XmpMeta parseString(String text) {
    final doc = XmlDocument.parse(_stripXpacket(text));
    final state = _State();

    // package:xml matches on the *qualified* name, so walk all elements and
    // filter by local name (crs:, rdf:, dc: prefixes vary by writer).
    for (final el in doc.rootElement.descendants.whereType<XmlElement>()) {
      final local = el.name.local;
      if (local == 'Description') {
        _absorb(el, state);
      } else if (local == 'Name' && state.name == null) {
        state.name = el.innerText.trim();
      }
    }

    return state.build();
  }

  static String _stripXpacket(String text) {
    var t = text.trim();
    if (t.startsWith('<?xpacket')) {
      final end = t.indexOf('?>');
      if (end > 0) t = t.substring(end + 2).trim();
    }
    return t;
  }

  static void _absorb(XmlElement el, _State s) {
    for (final a in el.attributes) {
      final local = _localName(a.qualifiedName);
      final value = a.value.trim();
      if (value.isEmpty) continue;

      final prop = _props[local];
      if (prop != null) {
        prop.apply(s, value);
        continue;
      }

      // HSL: <Channel><Hue|Saturation|Luminance>
      for (final entry in _hslChannels.entries) {
        final channel = entry.value;
        for (final (suffix, field) in const [
          ('Hue', 'hue'),
          ('Saturation', 'saturation'),
          ('Luminance', 'luminance'),
        ]) {
          if (local == '$channel$suffix') {
            s.setHsl(entry.key, field, double.tryParse(value));
          }
        }
      }
    }
  }

  static String _localName(String qualified) {
    final i = qualified.indexOf(':');
    return i < 0 ? qualified : qualified.substring(i + 1);
  }
}

class _Prop {
  const _Prop.d(this.kind2)
      : kind = 'd',
        zone = null,
        field = null;
  const _Prop.s(this.kind2)
      : kind = 's',
        zone = null,
        field = null;
  const _Prop.wbMode()
      : kind = 'wbMode',
        kind2 = null,
        zone = null,
        field = null;
  const _Prop.cg(this.zone, this.field) : kind = 'cg', kind2 = null;

  final String kind; // d | s | wbMode | cg
  final String? kind2;
  final String? zone;
  final String? field;

  void apply(_State s, String value) {
    switch (kind) {
      case 'd':
        s.setDouble(kind2!, double.tryParse(value));
      case 's':
        s.setString(kind2!, value);
      case 'wbMode':
        s.wbMode = value;
      case 'cg':
        s.setColorGrade(zone!, field!, double.tryParse(value));
    }
  }
}

class _State {
  String? name;
  String? wbMode;
  final Map<String, double> doubles = {};
  final Map<String, String> strings = {};
  final Map<XmpHslColor, HslAdjustment> hsl = {};
  final Map<String, Map<String, double>> colorGrade = {};

  void setDouble(String key, double? v) {
    if (v != null) doubles[key] = v;
  }

  void setString(String key, String v) {
    if (key == 'name') {
      name = v;
    } else {
      strings[key] = v;
    }
  }

  void setHsl(XmpHslColor color, String field, double? v) {
    if (v == null) return;
    final cur = hsl[color] ?? const HslAdjustment();
    hsl[color] = HslAdjustment(
      hue: field == 'hue' ? v : cur.hue,
      saturation: field == 'saturation' ? v : cur.saturation,
      luminance: field == 'luminance' ? v : cur.luminance,
    );
  }

  void setColorGrade(String zone, String field, double? v) {
    if (v == null) return;
    colorGrade.putIfAbsent(zone, () => {})[field] = v;
  }

  XmpMeta build() {
    // ProcessVersion is written as "11.0" (major.minor); 2012-era params
    // mean major >= 2.
    final pvMajor =
        doubles['processVersion'] != null ? doubles['processVersion']! ~/ 1 : null;

    WbInfo? wb;
    final temp = doubles['temperature'];
    final tnt = doubles['tint'];
    if (wbMode != null || temp != null || tnt != null) {
      wb = WbInfo(mode: wbMode, temperature: temp, tint: tnt);
    }

    return XmpMeta(
      name: name,
      description: strings['description'],
      processVersion: pvMajor,
      whiteBalance: wb,
      exposure: doubles['exposure'],
      contrast: doubles['contrast'],
      highlights: doubles['highlights'],
      shadows: doubles['shadows'],
      whites: doubles['whites'],
      blacks: doubles['blacks'],
      vibrance: doubles['vibrance'],
      saturation: doubles['saturation'],
      clarity: doubles['clarity'],
      texture: doubles['texture'],
      dehaze: doubles['dehaze'],
      shadowTint: doubles['shadowTint'],
      toneCurve: strings['toneCurve'],
      toneCurveRed: strings['toneCurveRed'],
      toneCurveGreen: strings['toneCurveGreen'],
      toneCurveBlue: strings['toneCurveBlue'],
      parametricShadows: doubles['parametricShadows'],
      parametricDarks: doubles['parametricDarks'],
      parametricLights: doubles['parametricLights'],
      parametricHighlights: doubles['parametricHighlights'],
      hsl: hsl.isEmpty ? null : hsl,
      colorGradeHigh: _cg('high'),
      colorGradeMid: _cg('mid'),
      colorGradeShadow: _cg('shadow'),
      colorGradeBalance: doubles['colorGradeBalance'],
      colorGradeBlending: doubles['colorGradeBlending'],
      colorGradeGlobalSaturation: doubles['colorGradeGlobalSaturation'],
      splitToningShadowHue: doubles['splitToningShadowHue'],
      splitToningShadowSaturation: doubles['splitToningShadowSaturation'],
      splitToningHighlightHue: doubles['splitToningHighlightHue'],
      splitToningHighlightSaturation: doubles['splitToningHighlightSaturation'],
      splitToningBalance: doubles['splitToningBalance'],
      sharpening: doubles['sharpening'],
      sharpenDetail: doubles['sharpenDetail'],
      sharpenRadius: doubles['sharpenRadius'],
      sharpenEdgeMasking: doubles['sharpenEdgeMasking'],
      grainAmount: doubles['grainAmount'],
      grainSize: doubles['grainSize'],
      grainRoughness: doubles['grainRoughness'],
      vignetteAmount: doubles['vignetteAmount'],
      vignetteMidpoint: doubles['vignetteMidpoint'],
      vignetteRoundness: doubles['vignetteRoundness'],
      vignetteFeather: doubles['vignetteFeather'],
      copyright: strings['copyright'],
      author: strings['author'],
    );
  }

  XmpColorGradeZone? _cg(String zone) {
    final m = colorGrade[zone];
    if (m == null) return null;
    final z = XmpColorGradeZone(
      hue: m['hue'],
      saturation: m['saturation'],
      luminance: m['luminance'],
    );
    return z.isNeutral ? null : z;
  }
}