import 'dart:convert';

import '../model/xmp_meta.dart';

/// Serializes [XmpMeta] back to a Lightroom-compatible .xmp sidecar.
class XmpGenerator {
  static String generate(XmpMeta m) {
    final attrs = StringBuffer();
    void d(String name, double? v) {
      if (v != null) attrs.write(' crs:$name="${_num(v)}"');
    }

    if (m.processVersion != null) {
      attrs.write(' crs:ProcessVersion="${m.processVersion}.0"');
    }
    if (m.whiteBalance != null) {
      if (m.whiteBalance!.mode != null) {
        attrs.write(' crs:WhiteBalance="${_esc(m.whiteBalance!.mode!)}"');
      }
      if (m.whiteBalance!.temperature != null) {
        attrs.write(' crs:Temp="${_num(m.whiteBalance!.temperature!)}"');
      }
      if (m.whiteBalance!.tint != null) {
        attrs.write(' crs:Tint="${_num(m.whiteBalance!.tint!)}"');
      }
    }
    d('Exposure2012', m.exposure);
    d('Contrast2012', m.contrast);
    d('Highlights2012', m.highlights);
    d('Shadows2012', m.shadows);
    d('Whites2012', m.whites);
    d('Blacks2012', m.blacks);
    d('Vibrance', m.vibrance);
    d('Saturation', m.saturation);
    d('Clarity2012', m.clarity);
    d('Texture', m.texture);
    d('Dehaze', m.dehaze);
    d('ShadowTint', m.shadowTint);
    _str(attrs, 'crs:ToneCurvePV2012', m.toneCurve);
    _str(attrs, 'crs:ToneCurvePV2012Red', m.toneCurveRed);
    _str(attrs, 'crs:ToneCurvePV2012Green', m.toneCurveGreen);
    _str(attrs, 'crs:ToneCurvePV2012Blue', m.toneCurveBlue);
    d('ParametricShadows', m.parametricShadows);
    d('ParametricDarks', m.parametricDarks);
    d('ParametricLights', m.parametricLights);
    d('ParametricHighlights', m.parametricHighlights);
    d('SplitToningShadowHue', m.splitToningShadowHue);
    d('SplitToningShadowSaturation', m.splitToningShadowSaturation);
    d('SplitToningHighlightHue', m.splitToningHighlightHue);
    d('SplitToningHighlightSaturation', m.splitToningHighlightSaturation);
    d('SplitToningBalance', m.splitToningBalance);
    d('Sharpening', m.sharpening);
    d('SharpenDetail', m.sharpenDetail);
    d('SharpenRadius', m.sharpenRadius);
    d('SharpenEdgeMasking', m.sharpenEdgeMasking);
    d('GrainAmount', m.grainAmount);
    d('GrainSize', m.grainSize);
    d('GrainRoughness', m.grainRoughness);
    d('PostCropVignetteAmount', m.vignetteAmount);
    d('PostCropVignetteMidpoint', m.vignetteMidpoint);
    d('PostCropVignetteRoundness', m.vignetteRoundness);
    d('PostCropVignetteFeather', m.vignetteFeather);
    d('ColorGradeBalance', m.colorGradeBalance);
    d('ColorGradeBlending', m.colorGradeBlending);
    d('ColorGradeGlobalSat', m.colorGradeGlobalSaturation);
    _cg(attrs, 'Midtone', m.colorGradeMid);
    _cg(attrs, 'Shadow', m.colorGradeShadow);
    _cg(attrs, 'Highlight', m.colorGradeHigh);

    final hsl = m.hsl;
    if (hsl != null) {
      const channels = {
        XmpHslColor.red: 'Red',
        XmpHslColor.orange: 'Orange',
        XmpHslColor.yellow: 'Yellow',
        XmpHslColor.green: 'Green',
        XmpHslColor.aqua: 'Aqua',
        XmpHslColor.blue: 'Blue',
        XmpHslColor.purple: 'Purple',
        XmpHslColor.magenta: 'Magenta',
      };
      for (final entry in channels.entries) {
        final adj = hsl[entry.key];
        if (adj == null) continue;
        d('${entry.value}Hue', adj.hue);
        d('${entry.value}Saturation', adj.saturation);
        d('${entry.value}Luminance', adj.luminance);
      }
    }

    final name = m.name;
    return '''<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about=""$attrs xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"${name == null ? '' : ' crs:Name="${_esc(name)}"'} xmlns:dc="http://purl.org/dc/elements/1.1/"${m.copyright == null ? '' : ' dc:rights="${_esc(m.copyright!)}"'}${m.author == null ? '' : ' dc:creator="${_esc(m.author!)}"'} xmlns:xmp="http://ns.adobe.com/xap/1.0/"/>
 </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>
''';
  }

  static List<int> generateBytes(XmpMeta m) => utf8.encode(generate(m));

  static void _str(StringBuffer b, String name, String? v) {
    if (v != null && v.trim().isNotEmpty) b.write(' $name="${_esc(v)}"');
  }

  static void _cg(StringBuffer b, String zone, XmpColorGradeZone? z) {
    if (z == null) return;
    d2(b, 'ColorGrade${zone}Hue', z.hue);
    d2(b, 'ColorGrade${zone}Sat', z.saturation);
    d2(b, 'ColorGrade${zone}Lum', z.luminance);
  }

  static void d2(StringBuffer b, String name, double? v) {
    if (v != null) b.write(' crs:$name="${_num(v)}"');
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}