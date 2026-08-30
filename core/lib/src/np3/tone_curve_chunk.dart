import 'dart:typed_data';

import '../model/colors.dart';

/// Layout of the custom tone curve extension chunk (578-byte payload).
///
/// Confirmed by diffing single-variable samples from
/// sssota/nikon-flexible-color-picture-control (MIT):
///
/// ```
/// 0x00  8 bytes   constant header 49 30 00 ff 00 ff 01 00
/// 0x08  1 byte    point count N (2..20), includes the 2 anchors
/// 0x09  2 bytes   reserved 00 00
/// 0x0b  40 bytes  N (x,y) uint8 point pairs, rest zero-filled.
///                 By observation the last two points are always the
///                 white anchor (255,255) then the black anchor (0,0).
/// 0x33  15 bytes  reserved zeros
/// 0x42  512 bytes 256 x uint16 BE LUT: lut[i] = output 0..32767 for
///                 8-bit input i+1 (input 0 is implicitly 0).
/// ```
abstract final class Np3ToneCurveChunk {
  static const int tag = 0x00000002; // TLV tag for the chunk entry
  static const int header = 0x493000ff00ff0100; // as 8 separate bytes below
  static const List<int> headerBytes = [0x49, 0x30, 0x00, 0xff, 0x00, 0xff, 0x01, 0x00];
  static const int pointCountOffset = 8;
  static const int pointsOffset = 11;
  static const int maxPoints = 20;
  static const int lutOffset = 66;
  static const int lutEntries = 256;
  static const int chunkLength = lutOffset + lutEntries * 2; // 578

  static ToneCurve decode(Uint8List chunk) {
    if (chunk.length != chunkLength) {
      throw FormatException(
          'tone curve chunk must be $chunkLength bytes, got ${chunk.length}');
    }
    final count = chunk[pointCountOffset];
    final points = <Point>[];
    for (var i = 0; i < count; i++) {
      points.add(Point(chunk[pointsOffset + i * 2], chunk[pointsOffset + i * 2 + 1]));
    }
    final lut = <int>[];
    for (var i = 0; i < lutEntries; i++) {
      final o = lutOffset + i * 2;
      lut.add((chunk[o] << 8) | chunk[o + 1]);
    }
    return ToneCurve(lut: lut, points: points);
  }

  static Uint8List encode(ToneCurve curve) {
    final points = curve.points;
    if (points.length < 2 || points.length > maxPoints) {
      throw ArgumentError(
          'tone curve needs 2..$maxPoints points (including anchors)');
    }
    if (points.last.x != 0 || points.last.y != 0 || points[points.length - 2].x != 255 ||
        points[points.length - 2].y != 255) {
      throw ArgumentError('last two points must be the white (255,255) then black (0,0) anchors');
    }
    if (curve.lut.length != lutEntries) {
      throw ArgumentError('LUT must have exactly $lutEntries entries');
    }

    final out = BytesBuilder();
    out.add(headerBytes);
    out.addByte(points.length);
    out.addByte(0x00);
    out.addByte(0x00);
    final pointSlots = List<int>.filled(maxPoints * 2, 0);
    for (var i = 0; i < points.length; i++) {
      pointSlots[i * 2] = points[i].x & 0xff;
      pointSlots[i * 2 + 1] = points[i].y & 0xff;
    }
    out.add(pointSlots);
    out.add(List<int>.filled(15, 0));
    for (final v in curve.lut) {
      out.addByte((v >> 8) & 0xff);
      out.addByte(v & 0xff);
    }
    return out.toBytes();
  }
}