import 'dart:typed_data';

import '../model/colors.dart';
import '../model/nikon_params.dart';
import '../np3/np3_codec.dart';

/// The camera-side "PictureControl DataSet" (Z50II MTP spec section 9.9).
///
/// This is the in-camera representation of a Picture Control — what
/// `SetPicCtrlData` (0x90CD) accepts and `GetPicCtrlData` returns. It is
/// deliberately coarser than the NP3 flexible format: tone sliders are
/// quarter-step bytes, and the only custom curve is a single 257-point
/// 8-bit LUT.
///
/// ```
/// offset  size  field
/// 0       2     BasePictureControl
/// 2       20    RegistrationName (19 ASCII chars + 0x00)
/// 22      1     ApplyLevel (0..100 step 10)
/// 23      1     QuickSharpFlag (0 off, 1 on)
/// 24      1     QuickSharp
/// 25      1     Sharpening
/// 26      1     MiddleRangeSharpening
/// 27      1     Clarity
/// 28      1     Contrast
/// 29      1     Brightness
/// 30      1     Saturation
/// 31      1     Hue
/// 32      1     FilterEffects
/// 33      1     Toning
/// 34      1     ToningDensity
/// 35      1     CustomCurveFlag (0 off, 1 on)
/// 36      578   CustomCurveData (only when the flag is 1)
/// ```
///
/// Slider bytes are signed 8-bit quarter steps: stored value N means
/// N x 0.25, and -128 means Auto (ignored for our purpose — we always send
/// concrete values).
class PicCtrlDataSet {
  PicCtrlDataSet({
    required this.basePictureControl,
    required this.registrationName,
    this.applyLevel = 100,
    this.quickSharpFlag = false,
    this.quickSharp = 0,
    this.sharpening = 0,
    this.middleRangeSharpening = 0,
    this.clarity = 0,
    this.contrast = 0,
    this.brightness = 0,
    this.saturation = 0,
    this.hue = 0,
    this.filterEffects = 0,
    this.toning = 0,
    this.toningDensity = 0,
    this.customCurveFlag = false,
    this.lut,
  });

  static const int nameBytes = 20;
  static const int headerSize = 36;
  static const int lutSize = 578; // 64 header + 257 x u16
  static const int baseSize = headerSize;
  static const int curvedSize = headerSize + lutSize;

  static const int auto = -128;

  final int basePictureControl;
  final String registrationName;
  final int applyLevel;
  final bool quickSharpFlag;
  final int quickSharp;
  final int sharpening;
  final int middleRangeSharpening;
  final int clarity;
  final int contrast;
  final int brightness;
  final int saturation;
  final int hue;
  final int filterEffects;
  final int toning;
  final int toningDensity;
  final bool customCurveFlag;

  /// 514 bytes: 257 x u16 little-endian, values 0..255. Null when the
  /// curve flag is off.
  final Uint8List? lut;

  int get byteLength => customCurveFlag ? curvedSize : baseSize;

  Uint8List encode() {
    final name = registrationName;
    if (name.length > 19) {
      throw ArgumentError.value(name, 'registrationName', 'max 19 chars');
    }
    final out = Uint8List(byteLength);
    _le16(out, 0, basePictureControl);
    final nm = Uint8List(nameBytes);
    for (var i = 0; i < name.length; i++) {
      final c = name.codeUnitAt(i);
      if (c < 0x20 || c > 0x7e) {
        throw ArgumentError.value(name, 'registrationName', 'must be printable ASCII');
      }
      nm[i] = c;
    }
    out.setRange(2, 2 + nameBytes, nm);
    out[22] = applyLevel;
    out[23] = quickSharpFlag ? 1 : 0;
    out[24] = _s8(quickSharp);
    out[25] = _s8(sharpening);
    out[26] = _s8(middleRangeSharpening);
    out[27] = _s8(clarity);
    out[28] = _s8(contrast);
    out[29] = _s8(brightness);
    out[30] = _s8(saturation);
    out[31] = _s8(hue);
    out[32] = _s8(filterEffects);
    out[33] = _s8(toning);
    out[34] = _s8(toningDensity);
    out[35] = customCurveFlag ? 1 : 0;
    if (customCurveFlag) {
      final l = lut;
      if (l == null || l.length != lutSize) {
        throw StateError('customCurveFlag set but lut missing/short');
      }
      out.setRange(headerSize, curvedSize, l);
    }
    return out;
  }

  static PicCtrlDataSet decode(List<int> b) {
    if (b.length != baseSize && b.length != curvedSize) {
      throw FormatException('PictureControl DataSet must be $baseSize or '
          '$curvedSize bytes, got ${b.length}');
    }
    final flag = b[35] != 0;
    return PicCtrlDataSet(
      basePictureControl: _readLe16(b, 0),
      registrationName: String.fromCharCodes(b.sublist(2, 22))
          .split('\x00')
          .first
          .trim(),
      applyLevel: b[22],
      quickSharpFlag: b[23] != 0,
      quickSharp: _u8(b[24]),
      sharpening: _u8(b[25]),
      middleRangeSharpening: _u8(b[26]),
      clarity: _u8(b[27]),
      contrast: _u8(b[28]),
      brightness: _u8(b[29]),
      saturation: _u8(b[30]),
      hue: _u8(b[31]),
      filterEffects: _u8(b[32]),
      toning: _u8(b[33]),
      toningDensity: _u8(b[34]),
      customCurveFlag: flag,
      lut: flag ? Uint8List.fromList(b.sublist(headerSize, curvedSize)) : null,
    );
  }

  // ------------------------------------------------------------- mapping --

  /// Build a camera-side data set from our Nikon projection.
  ///
  /// This is a *lossy, documented* projection: NP3's -100..+100 tone scale
  /// quantizes to the in-camera -3..+3 quarter-step sliders (Hue is
  /// -9..+9), sharpening (displayed -3..9) maps onto the in-camera
  /// 0..7, mid-range size -5..5 onto 0..9, and the color grading (split
  /// tones, 8-channel blender, blending/balance) has no native equivalent
  /// except an overall hue shift from the balance. The tone curve, when
  /// present, converts to the 257-point LUT.
  static PicCtrlDataSet fromNikon(NikonParams p, {required int baseCode}) {
    final name = Np3Codec.sanitizeNp3Name(p.name ?? 'Phos');
    return PicCtrlDataSet(
      basePictureControl: baseCode,
      registrationName: name.length > 19 ? name.substring(0, 19) : name,
      applyLevel: 100,
      quickSharpFlag: false,
      quickSharp: 0,
      // NP3 stores display units (byte = 128 + 4v); the in-camera byte is the
      // number of quarter steps (byte = 4 x display), so multiply by 4 and
      // clamp to the in-camera range (0..7 -> 0..28 quarter steps).
      sharpening: _clamp(
          p.sharpening == null ? 0 : (p.sharpening! * 4).round(), 0, 28),
      middleRangeSharpening: p.midRangeSharpening == null
          ? 0
          : _clamp(((p.midRangeSharpening! + 5) / 10 * 36).round(), 0, 36),
      clarity: _np3Tone(p.clarity == null ? null : p.clarity! / 5 * 100),
      contrast: _np3Tone(p.contrast),
      brightness: _np3Tone(p.blackLevel != null || p.whiteLevel != null
          ? ((p.blackLevel! + p.whiteLevel!) / 2)
          : null),
      saturation: _np3Tone(p.saturation),
      hue: p.gradingBalance == null
          ? 0
          : _clamp((p.gradingBalance! / 100 * 36).round(), -36, 36),
      filterEffects: 0,
      toning: 0,
      toningDensity: 0,
      customCurveFlag: p.hasToneCurve,
      lut: p.hasToneCurve ? lutFromToneCurve(p.toneCurve!) : null,
    );
  }

  /// NP3 -100..+100 to in-camera quarter steps, clamped to -3..+3
  /// (12 quarter steps).
  static int _np3Tone(num? v) =>
      v == null ? 0 : _clamp((v / 100 * 12).round(), -12, 12);

  /// Base Picture Control code from a profile hint (spec 9.9.1).
  static int baseCodeFor(String? hint) {
    final h = (hint ?? '').toLowerCase();
    if (h.contains('neutral')) return 2;
    if (h.contains('vivid')) return 3;
    if (h.contains('flat mono')) return 9;
    if (h.contains('deep tone')) return 10;
    if (h.contains('rich tone')) return 11;
    if (h.contains('mono')) return 4;
    if (h.contains('portrait')) return 5;
    if (h.contains('landscape')) return 6;
    if (h.contains('flat')) return 7;
    if (h.contains('auto')) return 8;
    return 1; // Standard
  }

  /// 578-byte camera curve: 64-byte host header (Nikon layout) + 257 x u16
  /// little-endian 8-bit LUT.
  ///
  /// The header reuses our NP3 chunk prefix (ID 0x49 0x30, in/out ranges,
  /// gamma, spline points), which matches Nikon's own header layout
  /// (spec 9.9.17.1) byte for byte.
  static Uint8List lutFromToneCurve(ToneCurve curve) {
    final points = curve.points;
    if (points.length < 2 || points.length > 20) {
      throw ArgumentError('curve needs 2..20 points, got ${points.length}');
    }
    if (curve.lut.length != 256) {
      throw ArgumentError('curve LUT must have 256 entries');
    }
    final out = Uint8List(lutSize);
    // Header (64 bytes).
    out[0] = 0x49;
    out[1] = 0x30;
    out[2] = 0; // input min (black point)
    out[3] = 255; // input max
    out[4] = 0; // output min
    out[5] = 255; // output max
    out[6] = 1; // gamma integer
    out[7] = 0; // gamma fractional
    out[8] = points.length;
    for (var i = 0; i < points.length; i++) {
      out[9 + i * 2] = points[i].x & 0xff;
      out[9 + i * 2 + 1] = points[i].y & 0xff;
    }
    // 49..63 stay zero.
    // LUT: 257 points, Data0 = input 0.
    out[64] = 0;
    out[65] = 0;
    for (var i = 0; i < 256; i++) {
      final v = (curve.lut[i] * 255 / 32767).round().clamp(0, 255);
      final o = 66 + i * 2;
      out[o] = v & 0xff;
      out[o + 1] = (v >> 8) & 0xff;
    }
    return out;
  }

  /// The 257-point 8-bit LUT read back from the camera (0..255 each).
  List<int>? readLut8() {
    final l = lut;
    if (l == null) return null;
    final pts = List<int>.filled(257, 0);
    pts[0] = l[64] | (l[65] << 8);
    for (var i = 1; i < 257; i++) {
      final o = 64 + i * 2;
      pts[i] = l[o] | (l[o + 1] << 8);
    }
    return pts;
  }

  @override
  String toString() => 'PicCtrlDataSet(base=$basePictureControl, '
      '“$registrationName”, contrast=$contrast, saturation=$saturation, '
      'curve=$customCurveFlag)';
}

int _le16(List<int> b, int off, int v) {
  b[off] = v & 0xff;
  b[off + 1] = (v >> 8) & 0xff;
  return v;
}

int _readLe16(List<int> b, int off) => b[off] | (b[off + 1] << 8);

/// Signed 8-bit: value v in -128..127 to its two's-complement byte (returns
/// the byte value for writing).
int _s8(int v) {
  if (v < -128 || v > 127) {
    throw ArgumentError.value(v, 'slider', 'out of signed byte range');
  }
  return v & 0xff;
}

/// Byte back to a signed value.
int _u8(int b) => b >= 128 ? b - 256 : b;

int _clamp(num v, int lo, int hi) => v.clamp(lo, hi).toInt();