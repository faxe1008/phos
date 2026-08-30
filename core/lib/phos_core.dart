/// phos_core: vendor-neutral camera recipe core.
///
/// - [UniversalRecipe]: the canonical recipe model (identity, provenance,
///   Nikon projection, preserved source metadata, fidelity report).
/// - NP3/.NCP parse + generate ([Np3Codec]).
/// - Lightroom XMP import/export ([XmpParser], [XmpGenerator]).
/// - Fujifilm recipe import ([FujiRecipeParser]).
/// - Fidelity-reporting conversions ([RecipeConverter]).
/// - Shipped style catalog ([BuiltinCatalog]).
library;

export 'src/camera/framing.dart';
export 'src/camera/ops.dart';
export 'src/camera/pic_ctrl.dart';
export 'src/camera/session.dart';
export 'src/camera/transport.dart';
export 'src/catalog/builtin_catalog.dart';
export 'src/fuji/fuji_recipe_parser.dart';
export 'src/mapping/curve_builder.dart';
export 'src/mapping/fuji_to_nikon.dart';
export 'src/mapping/recipe_converter.dart';
export 'src/mapping/target_profile.dart';
export 'src/mapping/xmp_to_nikon.dart';
export 'src/model/colors.dart';
export 'src/model/fuji_meta.dart';
export 'src/model/mapping_report.dart';
export 'src/model/nikon_params.dart';
export 'src/model/universal_recipe.dart';
export 'src/model/xmp_meta.dart';
export 'src/np3/np3_codec.dart';
export 'src/np3/np3_template.dart';
export 'src/np3/tone_curve_chunk.dart';
export 'src/xmp/xmp_generator.dart';
export 'src/xmp/xmp_parser.dart';