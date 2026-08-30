import 'dart:convert';
import 'dart:typed_data';

import '../model/colors.dart';
import '../model/nikon_params.dart';
import 'np3_template.dart';
import 'tone_curve_chunk.dart';

/// Low-level .NP3 / .NCP parser and generator.
///
/// Parsing scans the TLV entries (robust to the presence/absence of the
/// comment and tone-curve extension chunks). Generation patches the confirmed
/// offsets of a known-good base template so unknown bytes are preserved.
class Np3Codec {
  static const List<int> _magic = [0x4e, 0x43, 0x50, 0x00];
  static const int _commentTag = 0x00010100;

  // ---------------------------------------------------------------- parse --

  static NikonParams parse(List<int> data) {
    if (data.length < 16 ||
        data[0] != _magic[0] ||
        data[1] != _magic[1] ||
        data[2] != _magic[2] ||
        data[3] != _magic[3]) {
      throw FormatException('not an NP3/NCP file (bad magic)');
    }

    final view = ByteData.sublistView(Uint8List.fromList(data));
    final entries = <int, Uint8List>{};
    var off = 16;
    while (off + 8 <= data.length) {
      final tag = view.getUint32(off, Endian.big);
      final len = view.getUint32(off + 4, Endian.big);
      // The file ends with a 4-byte all-zero trailer (tag 0, len 0).
      if (tag == 0) break;
      final vs = off + 8;
      final ve = vs + len;
      if (ve > data.length) break;
      entries[tag >> 8] = Uint8List.sublistView(Uint8List.fromList(data), vs, ve);
      off = ve;
    }

    return _decodeEntries(entries);
  }

  static NikonParams _decodeEntries(Map<int, Uint8List> e) {
    String name = '';
    if (e.containsKey(2)) {
      name = _readName(e[2]!);
    }

    final hasCurve = _isSentinel(e[25]);
    final contrast = hasCurve ? null : _s8(e, 25);
    final highlights = hasCurve ? null : _s8(e, 26);
    final shadows = hasCurve ? null : _s8(e, 27);
    final whiteLevel = hasCurve ? null : _s8(e, 28);
    final blackLevel = hasCurve ? null : _s8(e, 29);
    final saturation = _s8(e, 30);

    final sharpening = _q4(e, 6);
    final clarity = _q4(e, 7);
    final midRange = _q4(e, 22);

    final blender = _decodeBlender(e[31]);
    final grading = _decodeGrading(e[32]);

    ToneCurve? curve;
    if (e.containsKey(Np3ToneCurveChunk.tag >> 8)) {
      curve = Np3ToneCurveChunk.decode(e[Np3ToneCurveChunk.tag >> 8]!);
    }

    String? comment;
    if (e.containsKey(_commentTag >> 8)) {
      comment = _readComment(e[_commentTag >> 8]!);
    }

    return NikonParams(
      name: name.isEmpty ? null : name,
      comment: comment,
      contrast: contrast,
      highlights: highlights,
      shadows: shadows,
      whiteLevel: whiteLevel,
      blackLevel: blackLevel,
      saturation: saturation,
      sharpening: sharpening,
      clarity: clarity,
      midRangeSharpening: midRange,
      colorBlender: blender,
      colorGrading: grading.$1,
      gradingBlending: grading.$2,
      gradingBalance: grading.$3,
      toneCurve: curve,
    );
  }

  static bool _isSentinel(Uint8List? v) =>
      v != null && v.length >= 2 && v[0] == 0x01 && v[1] == 0x01;

  static int _s8(Map<int, Uint8List> e, int tag) {
    final v = e[tag];
    if (v == null || v.isEmpty) return 0;
    return v[0] - 0x80;
  }

  static double _q4(Map<int, Uint8List> e, int tag) {
    final v = e[tag];
    if (v == null || v.isEmpty) return 0;
    return (v[0] - 0x80) / 4.0;
  }

  static String _readName(Uint8List v) {
    final end = v.indexOf(0);
    final bytes = end < 0 ? v : v.sublist(0, end);
    return latin1.decode(bytes).trimRight();
  }

  static String _readComment(Uint8List v) {
    var end = v.length;
    while (end > 0 && v[end - 1] == 0) {
      end--;
    }
    return utf8.decode(v.sublist(0, end), allowMalformed: true);
  }

  static Map<String, ColorChannel> _decodeBlender(Uint8List? v) {
    final out = <String, ColorChannel>{};
    if (v == null || v.length < 24) return out;
    for (var i = 0; i < 8; i++) {
      final base = i * 3;
      out[ColorChannel.channelNames[i]] = ColorChannel(
        hue: v[base] - 0x80,
        chroma: v[base + 1] - 0x80,
        brightness: v[base + 2] - 0x80,
      );
    }
    return out;
  }

  static (Map<String, GradingZone>, int?, int?) _decodeGrading(Uint8List? v) {
    final out = <String, GradingZone>{};
    if (v == null || v.length < 20) {
      return (out, null, null);
    }
    for (var i = 0; i < 3; i++) {
      final b = i * 4;
      final hue = ((v[b] & 0x0f) << 8) | v[b + 1];
      out[GradingZone.zoneNames[i]] = GradingZone(
        hue: hue,
        chroma: v[b + 2] - 0x80,
        brightness: v[b + 3] - 0x80,
      );
    }
    return (out, v[16] - 0x80, v[18] - 0x80);
  }

  // ------------------------------------------------------------ generate --

  /// Generate a .NP3 byte string from [p].
  ///
  /// [template] defaults to the embedded vanilla base. Pass a camera-derived
  /// template if a specific firmware's unknown bytes must be preserved.
  static Uint8List generate(NikonParams p, {List<int>? template}) {
    final base = template ?? kVanillaTemplate;
    if (base.length < Np3Offsets.baseSize) {
      throw ArgumentError('template must be at least ${Np3Offsets.baseSize} bytes');
    }
    final buf = Uint8List.fromList(base.sublist(0, Np3Offsets.baseSize));

    _writeName(buf, p.name ?? 'Recipe');

    // Detail (quarter-step). Unspecified fields keep the flexible-color base
    // defaults (sharpening 2.0, clarity 0.5, mid-range 1.0) matching the
    // known-good template, matching sssota's documented defaults.
    _writeQ4(buf, Np3Offsets.sharpening, p.sharpening ?? 2.0, -3, 9);
    _writeQ4(buf, Np3Offsets.clarity, p.clarity ?? 0.5, -5, 5);
    _writeQ4(buf, Np3Offsets.midRangeSharpening, p.midRangeSharpening ?? 1.0, -5, 5);

    final hasCurve = p.hasToneCurve;
    _writeToneOrSentinel(buf, Np3Offsets.contrast, p.contrast ?? 0, hasCurve);
    _writeToneOrSentinel(buf, Np3Offsets.highlights, p.highlights ?? 0, hasCurve);
    _writeToneOrSentinel(buf, Np3Offsets.shadows, p.shadows ?? 0, hasCurve);
    _writeToneOrSentinel(buf, Np3Offsets.whiteLevel, p.whiteLevel ?? 0, hasCurve);
    _writeToneOrSentinel(buf, Np3Offsets.blackLevel, p.blackLevel ?? 0, hasCurve);
    _writeS8(buf, Np3Offsets.saturation, p.saturation ?? 0);

    _writeBlender(buf, p.colorBlender);
    _writeGrading(buf, p);

    final out = BytesBuilder();
    out.add(buf);
    if (p.comment != null && (p.comment!.trim().isNotEmpty)) {
      out.add(_commentEntry(p.comment!));
    }
    if (hasCurve) {
      final payload = Np3ToneCurveChunk.encode(p.toneCurve!);
      out.add(_tlv(Np3ToneCurveChunk.tag, payload));
    }
    out.add([0x00, 0x00, 0x00, 0x00]); // trailer
    return out.toBytes();
  }

  static Uint8List _tlv(int tag, List<int> payload) {
    final b = BytesBuilder();
    final t = ByteData(8);
    t.setUint32(0, tag, Endian.big);
    t.setUint32(4, payload.length, Endian.big);
    b.add(t.buffer.asUint8List());
    b.add(payload);
    return b.toBytes();
  }

  static Uint8List _commentEntry(String comment) {
    final enc = utf8.encode(comment);
    if (enc.any((b) => b == 0)) {
      throw ArgumentError('comment must not contain NUL characters');
    }
    var payload = [...enc, 0x00];
    if (payload.length.isOdd) payload = [...payload, 0x00];
    return _tlv(_commentTag, payload);
  }

  static void _writeName(Uint8List buf, String name) {
    final clean = sanitizeNp3Name(name);
    final bytes = latin1.encode(clean);
    for (var i = 0; i < 20; i++) {
      buf[Np3Offsets.name + i] = i < bytes.length ? bytes[i] : 0;
    }
  }

  /// Trim [name] to the NP3 name constraints (1..19 ASCII printable chars).
  static String sanitizeNp3Name(String name) {
    final sb = StringBuffer();
    for (final r in name.runes) {
      if (sb.length >= 19) break;
      final c = r;
      if (c >= 0x20 && c <= 0x7e) sb.writeCharCode(c);
    }
    final s = sb.toString();
    return s.isEmpty ? 'Recipe' : s;
  }

  static void _writeS8(Uint8List buf, int off, int v) {
    buf[off] = 0x80 + (v.clamp(-100, 100));
  }

  static void _writeToneOrSentinel(Uint8List buf, int off, int v, bool sentinel) {
    if (sentinel) {
      buf[off] = 0x01;
      buf[off + 1] = 0x01;
    } else {
      buf[off] = 0x80 + (v.clamp(-100, 100));
      // second byte (off+1) is preserved from the template
    }
  }

  static void _writeQ4(Uint8List buf, int off, double v, int min, int max) {
    final stepped = (v.clamp(min.toDouble(), max.toDouble()) * 4).round();
    buf[off] = 0x80 + stepped;
  }

  static void _writeBlender(Uint8List buf, Map<String, ColorChannel>? channels) {
    for (var i = 0; i < 8; i++) {
      final c = channels?[ColorChannel.channelNames[i]] ??
          const ColorChannel();
      final base = Np3Offsets.colorBlender + i * 3;
      buf[base] = 0x80 + (c.hue.clamp(-100, 100));
      buf[base + 1] = 0x80 + (c.chroma.clamp(-100, 100));
      buf[base + 2] = 0x80 + (c.brightness.clamp(-100, 100));
    }
    // bytes 24..27 of the blender entry are unconfirmed: preserved as-is.
  }

  static void _writeGrading(Uint8List buf, NikonParams p) {
    final zones = p.colorGrading;
    final offsets = [
      Np3Offsets.colorGradingHigh,
      Np3Offsets.colorGradingMid,
      Np3Offsets.colorGradingShadow,
    ];
    for (var i = 0; i < 3; i++) {
      final z = zones?[GradingZone.zoneNames[i]] ?? const GradingZone();
      final hue = z.hue.clamp(0, 4095);
      final o = offsets[i];
      buf[o] = 0x80 | ((hue >> 8) & 0x0f);
      buf[o + 1] = hue & 0xff;
      buf[o + 2] = 0x80 + (z.chroma.clamp(-100, 100));
      buf[o + 3] = 0x80 + (z.brightness.clamp(-100, 100));
    }
    buf[Np3Offsets.colorGradingBlending] =
        0x80 + (p.gradingBlending ?? 50).clamp(-100, 100);
    buf[Np3Offsets.colorGradingBalance] =
        0x80 + (p.gradingBalance ?? 0).clamp(-100, 100);
  }
}