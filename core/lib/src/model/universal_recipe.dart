import 'fuji_meta.dart';
import 'mapping_report.dart';
import 'nikon_params.dart';
import 'xmp_meta.dart';

/// A single entry in the catalog: a named style the app ships.
class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.nikon,
    this.tags = const [],
    this.previewImage,
    this.sourceUrl,
    this.author,
  });

  final String id;
  final String name;
  final String description;

  /// The style expressed directly in Nikon terms (catalog styles are
  /// authored for the target, so no conversion is needed to deploy them).
  final NikonParams nikon;
  final List<String> tags;
  final String? previewImage;

  /// Public page where this style was published (attribution).
  final String? sourceUrl;
  final String? author;

  UniversalRecipe toRecipe() => UniversalRecipe(
        id: 'catalog:$id',
        name: name,
        description: description,
        author: author,
        sourceFormat: SourceFormat.builtin,
        nikon: nikon,
        tags: tags,
        sourceUrl: sourceUrl,
      );
}

/// The vendor-neutral, canonical recipe representation.
///
/// Everything the app knows about a "look" flows through this model. NP3,
/// XMP, Fuji text, and future formats are adapters that populate it; the
/// [nikon] projection is what gets deployed to a Z body.
///
/// Design rules (from the brief):
///  * Original source artifacts are immutable; this object is a new version.
///  * Source metadata ([xmp], [fuji]) is preserved even for fields that do
///    not map to Nikon, so nothing is silently lost.
///  * Conversions carry a [mappingReport] with per-field fidelity.
class UniversalRecipe {
  UniversalRecipe({
    required this.id,
    required this.name,
    this.author,
    this.description,
    this.createdAt,
    this.modifiedAt,
    required this.sourceFormat,
    this.sourceUri,
    this.sourceUrl,
    this.checksumSha256,
    this.licenseNotes,
    this.sourceComment,
    this.nikon = const NikonParams(),
    this.xmp,
    this.fuji,
    this.whiteBalance,
    this.mappingReport,
    this.tags = const [],
    this.favorites = false,
  });

  // ---- identity -----------------------------------------------------------
  /// Mutable on purpose: importers reassign it to a stable, namespaced id
  /// (e.g. `filmrecipes:<slug>`) after conversion.
  String id;
  String name;
  String? author;
  String? description;
  DateTime? createdAt;
  DateTime? modifiedAt;

  // ---- provenance ---------------------------------------------------------
  SourceFormat sourceFormat;

  /// Where the file came from (disk path, URL, catalog id, ...).
  String? sourceUri;

  /// Web URL of the recipe's public source page, for attribution and
  /// "view original" links (e.g. the blog post a Fuji recipe was taken from).
  String? sourceUrl;

  /// SHA-256 of the original artifact bytes.
  String? checksumSha256;

  String? licenseNotes;

  /// Free-text comment attached to the source (NP3 comment chunk, XMP
  /// description, ...).
  String? sourceComment;

  // ---- the look -----------------------------------------------------------
  /// The Nikon projection of this recipe (what can actually be deployed).
  NikonParams nikon;

  /// Verbatim Lightroom source data, when imported from XMP.
  XmpMeta? xmp;

  /// Verbatim Fuji source data, when imported from a Fuji recipe.
  FujiMeta? fuji;

  /// White balance carried over from the source (metadata only; NP3 does not
  /// store WB).
  WbInfo? whiteBalance;

  // ---- conversion results --------------------------------------------------
  /// Set after a conversion run; null for natively-Nikon or catalog recipes.
  MappingReport? mappingReport;

  // ---- user organization ---------------------------------------------------
  List<String> tags;
  bool favorites;

  /// Human-readable overall fidelity, or null if no conversion was run.
  String? get fidelitySummary => mappingReport?.summary;

  /// Convenience: is this recipe a "converted" one (source != nikon native)?
  bool get isConverted =>
      mappingReport != null ||
      sourceFormat == SourceFormat.xmp ||
      sourceFormat == SourceFormat.fujiText;

  /// Return a copy with the given fields replaced (recipe objects are
  /// treated as versioned snapshots; edits produce new versions upstream).
  UniversalRecipe copyWith({
    String? name,
    String? author,
    String? description,
    SourceFormat? sourceFormat,
    String? sourceUri,
    String? sourceUrl,
    String? checksumSha256,
    String? licenseNotes,
    String? sourceComment,
    NikonParams? nikon,
    XmpMeta? xmp,
    FujiMeta? fuji,
    WbInfo? whiteBalance,
    MappingReport? mappingReport,
    List<String>? tags,
    bool? favorites,
    DateTime? modifiedAt,
  }) =>
      UniversalRecipe(
        id: id,
        name: name ?? this.name,
        author: author ?? this.author,
        description: description ?? this.description,
        createdAt: createdAt,
        modifiedAt: modifiedAt ?? DateTime.now(),
        sourceFormat: sourceFormat ?? this.sourceFormat,
        sourceUri: sourceUri ?? this.sourceUri,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        checksumSha256: checksumSha256 ?? this.checksumSha256,
        licenseNotes: licenseNotes ?? this.licenseNotes,
        sourceComment: sourceComment ?? this.sourceComment,
        nikon: nikon ?? this.nikon,
        xmp: xmp ?? this.xmp,
        fuji: fuji ?? this.fuji,
        whiteBalance: whiteBalance ?? this.whiteBalance,
        mappingReport: mappingReport ?? this.mappingReport,
        tags: tags ?? this.tags,
        favorites: favorites ?? this.favorites,
      );

  // ---- serialization -------------------------------------------------------
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (author != null) 'author': author,
        if (description != null) 'description': description,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
        'sourceFormat': sourceFormat.name,
        if (sourceUri != null) 'sourceUri': sourceUri,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (checksumSha256 != null) 'checksumSha256': checksumSha256,
        if (licenseNotes != null) 'licenseNotes': licenseNotes,
        if (sourceComment != null) 'sourceComment': sourceComment,
        'nikon': nikon.toJson(),
        if (xmp != null) 'xmp': xmp!.toJson(),
        if (fuji != null) 'fuji': fuji!.toJson(),
        if (whiteBalance != null) 'whiteBalance': whiteBalance!.toJson(),
        if (mappingReport != null) 'mappingReport': mappingReport!.toJson(),
        if (tags.isNotEmpty) 'tags': tags,
        if (favorites) 'favorites': true,
      };

  factory UniversalRecipe.fromJson(Map<String, Object?> j) => UniversalRecipe(
        id: j['id'] as String,
        name: j['name'] as String,
        author: j['author'] as String?,
        description: j['description'] as String?,
        createdAt: j['createdAt'] == null ? null : DateTime.parse(j['createdAt'] as String),
        modifiedAt: j['modifiedAt'] == null ? null : DateTime.parse(j['modifiedAt'] as String),
        sourceFormat:
            SourceFormat.values.byName(j['sourceFormat'] as String? ?? 'unknown'),
        sourceUri: j['sourceUri'] as String?,
        sourceUrl: j['sourceUrl'] as String?,
        checksumSha256: j['checksumSha256'] as String?,
        licenseNotes: j['licenseNotes'] as String?,
        sourceComment: j['sourceComment'] as String?,
        nikon: j['nikon'] == null
            ? const NikonParams()
            : NikonParams.fromJson((j['nikon'] as Map).cast<String, Object?>()),
        xmp: j['xmp'] == null ? null : XmpMeta.fromJson((j['xmp'] as Map).cast<String, Object?>()),
        fuji: j['fuji'] == null ? null : FujiMeta.fromJson((j['fuji'] as Map).cast<String, Object?>()),
        whiteBalance: j['whiteBalance'] == null
            ? null
            : WbInfo.fromJson((j['whiteBalance'] as Map).cast<String, Object?>()),
        mappingReport: j['mappingReport'] == null
            ? null
            : MappingReport.fromJson((j['mappingReport'] as Map).cast<String, Object?>()),
        tags: (j['tags'] as List? ?? const []).map((e) => e as String).toList(),
        favorites: j['favorites'] as bool? ?? false,
      );
}