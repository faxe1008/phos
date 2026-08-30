import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../fuji/fuji_recipe_parser.dart';
import '../model/nikon_params.dart';
import '../model/universal_recipe.dart';
import '../model/xmp_meta.dart';
import '../np3/np3_codec.dart';
import '../xmp/xmp_generator.dart';
import '../xmp/xmp_parser.dart';
import 'fuji_to_nikon.dart';
import 'target_profile.dart';
import 'xmp_to_nikon.dart';

/// Entry point for turning source artifacts (NP3 / XMP / Fuji text) into
/// versioned [UniversalRecipe]s, and for writing an NP3 back out.
///
/// Every import computes the SHA-256 of the original bytes for provenance and
/// runs the fidelity-reporting conversion, so nothing is silently lost.
class RecipeConverter {
  static const TargetProfile defaultTarget = TargetProfile.z50ii;

  // ------------------------------------------------------------- imports --

  static UniversalRecipe fromNp3(List<int> bytes, {String? name}) {
    final p = Np3Codec.parse(bytes);
    return UniversalRecipe(
      id: _newId(),
      name: name ?? p.name ?? 'Imported NP3',
      sourceFormat: SourceFormat.np3,
      checksumSha256: sha256Hex(bytes),
      nikon: p,
      sourceComment: p.comment,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
  }

  static UniversalRecipe fromXmp(List<int> bytes, {String? name}) {
    final meta = XmpParser.parse(bytes);
    final finalName = name ?? meta.name ?? 'Imported XMP';
    final (nikon, report) =
        XmpToNikon.convert(meta, name: Np3Codec.sanitizeNp3Name(finalName));
    return UniversalRecipe(
      id: _newId(),
      name: finalName,
      author: meta.author,
      description: meta.description,
      sourceFormat: SourceFormat.xmp,
      checksumSha256: sha256Hex(bytes),
      nikon: nikon,
      xmp: meta,
      whiteBalance: meta.whiteBalance,
      sourceComment: meta.description,
      mappingReport: report,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
  }

  static UniversalRecipe fromFujiText(String text, {String? name}) {
    final f = FujiRecipeParser.parse(text);
    final finalName = name ?? f.filmSimulation ?? 'Fuji recipe';
    final (nikon, report) =
        FujiToNikon.convert(f, name: Np3Codec.sanitizeNp3Name(finalName));
    return UniversalRecipe(
      id: _newId(),
      name: finalName,
      sourceFormat: SourceFormat.fujiText,
      checksumSha256: sha256Hex(utf8.encode(text)),
      nikon: nikon,
      fuji: f,
      whiteBalance: f.whiteBalanceMode != null
          ? WbInfo(
              mode: f.whiteBalanceMode,
              tint: _wbTint(f.wbRedShift, f.wbBlueShift),
            )
          : null,
      mappingReport: report,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
  }

  // ------------------------------------------------------------ outputs --

  /// Serialize a recipe's Nikon projection to a deployable .NP3 byte string.
  static List<int> toNp3(UniversalRecipe r) => Np3Codec.generate(r.nikon);

  /// Re-export an XMP-imported recipe back to a .xmp sidecar (lossless for
  /// the parsed fields).
  static List<int> toXmp(UniversalRecipe r) {
    final m = r.xmp;
    if (m == null) {
      throw StateError('recipe has no XMP source to re-export');
    }
    return XmpGenerator.generateBytes(m);
  }

  // ------------------------------------------------------------- helpers --

  static String _newId() {
    final rnd = math.Random.secure();
    final bytes = List<int>.generate(8, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static double? _wbTint(int? red, int? blue) {
    if (red == null && blue == null) return null;
    return ((red ?? 0) - (blue ?? 0)).toDouble();
  }

  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
}