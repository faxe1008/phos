import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:phos_core/phos_core.dart';

import 'nikon_filter.dart';

/// Renders style previews off the UI thread and caches the results.
///
/// Each render is a self-contained [Isolate.run] job that receives only
/// sendable data (JPEG bytes + JSON params) and returns JPEG bytes, so the
/// `image` objects never cross an isolate boundary.
///
/// The renderer is injectable so tests can run synchronously without
/// spawning isolates.
typedef PreviewRenderFn = Future<Uint8List> Function({
  required Uint8List baseJpeg,
  required NikonParams params,
  required int width,
  required int version,
});

typedef PreviewPlainRenderFn = Future<Uint8List> Function({
  required Uint8List baseJpeg,
  required int width,
});

class PreviewService {
  PreviewService({
    PreviewRenderFn? render,
    PreviewPlainRenderFn? plainRender,
  })  : _render = render ?? _isolated,
        _plainRender = plainRender ?? _plainIsolated;

  final PreviewRenderFn _render;
  final PreviewPlainRenderFn _plainRender;
  final Map<String, Uint8List> _cache = <String, Uint8List>{};

  static Future<Uint8List> _renderJob(
      Uint8List baseJpeg, String paramsJson, int width) async {
    final src = img.decodeImage(baseJpeg);
    if (src == null) throw const FormatException('undecodable base image');
    final p = NikonParams.fromJson(
        (jsonDecode(paramsJson) as Map).cast<String, Object?>());
    final out = NikonPreviewFilter.apply(src, p, width: width);
    return img.encodeJpg(out, quality: 88);
  }

  static Future<Uint8List> _isolated({
    required Uint8List baseJpeg,
    required NikonParams params,
    required int width,
    required int version,
  }) {
    return Isolate.run(
        () => _renderJob(baseJpeg, jsonEncode(params.toJson()), width));
  }

  static Future<Uint8List> _plainJob(Uint8List baseJpeg, int width) async {
    final src = img.decodeImage(baseJpeg);
    if (src == null) throw const FormatException('undecodable base image');
    var out = src;
    if (src.width != width) {
      final h = (src.height * width / src.width).round();
      out = img.copyResize(src,
          width: width,
          height: h,
          interpolation: img.Interpolation.linear);
    }
    return img.encodeJpg(out, quality: 88);
  }

  static Future<Uint8List> _plainIsolated({
    required Uint8List baseJpeg,
    required int width,
  }) {
    return Isolate.run(() => _plainJob(baseJpeg, width));
  }

  /// Render (or fetch from cache) a thumbnail of [params] applied to
  /// [baseJpeg]. [version] keys the cache so a new base image invalidates
  /// all previous renders.
  Future<Uint8List> renderThumbnail({
    required Uint8List baseJpeg,
    required NikonParams params,
    required int width,
    required int version,
  }) async {
    final key = 'v$version:$width:${jsonEncode(params.toJson())}';
    final hit = _cache[key];
    if (hit != null) return hit;
    final bytes = await _render(
      baseJpeg: baseJpeg,
      params: params,
      width: width,
      version: version,
    );
    _cache[key] = bytes;
    return bytes;
  }

  /// Render (or fetch from cache) the unmodified [baseJpeg] at [width] —
  /// the "original" side of an A/B comparison.
  Future<Uint8List> renderPlain({
    required Uint8List baseJpeg,
    required int width,
    required int version,
  }) async {
    final key = 'plain:v$version:$width';
    final hit = _cache[key];
    if (hit != null) return hit;
    final bytes = await _plainRender(baseJpeg: baseJpeg, width: width);
    _cache[key] = bytes;
    return bytes;
  }

  /// Encode the default generated preview card to JPEG.
  static Uint8List encodeDefaultCard({int maxW = 960}) {
    var card = generateDefaultPreviewCard();
    if (card.width > maxW) {
      final h = (card.height * maxW / card.width).round();
      card = img.copyResize(card,
          width: maxW, height: h, interpolation: img.Interpolation.linear);
    }
    return img.encodeJpg(card, quality: 90);
  }
}