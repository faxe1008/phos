import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:phos_core/phos_core.dart';

import '../camera/camera_link.dart';
import '../data/film_recipes_data.dart';
import '../import/import_service.dart';
import '../preview/preview_service.dart';

/// Central app state: the preview base image + the style library.
class AppModel extends ChangeNotifier {
  AppModel({
    Future<Directory> Function()? docDir,
    PreviewService? preview,
    CameraLink? cameraLink,
  }) : _docDirImpl = docDir ?? getApplicationDocumentsDirectory,
        preview = preview ?? PreviewService(),
        _cameraLink = cameraLink {
    load().catchError((Object e) => _setError('Failed to start: $e'));
  }

  final Future<Directory> Function() _docDirImpl;

  final PreviewService preview;

  CameraLink? _cameraLink;

  /// Send-to-camera link (USB MTP). Created lazily so tests and
  /// non-Android targets never touch the platform channel.
  CameraLink get cameraLink => _cameraLink ??= CameraLink();

  // ---------------------------------------------------------- preview --
  Uint8List? _baseJpeg;
  bool _hasCustomPreview = false;
  int _previewVersion = 0;

  Uint8List get baseJpeg => _baseJpeg ??= PreviewService.encodeDefaultCard();
  bool get hasCustomPreview => _hasCustomPreview;
  int get previewVersion => _previewVersion;

  // ----------------------------------------------------------- library --
  final List<UniversalRecipe> _imports = [];
  final List<UniversalRecipe> _builtins =
      BuiltinCatalog.styles.map((e) => e.toRecipe()).toList();
  final List<UniversalRecipe> _discoveries = _buildDiscoveries();
  bool _loaded = false;
  String? _busyMessage;

  bool get loaded => _loaded;
  String? get busyMessage => _busyMessage;
  List<UniversalRecipe> get imports => List.unmodifiable(_imports);
  List<UniversalRecipe> get builtins => _builtins;

  /// Shipped, read-in look from film.recipes (converted Fuji recipes).
  List<UniversalRecipe> get discoveries => _discoveries;

  List<UniversalRecipe> get allStyles =>
      [..._builtins, ..._discoveries, ..._imports];
  List<UniversalRecipe> get favorites =>
      allStyles.where((s) => s.favorites).toList();

  static const String _discoveryIdPrefix = 'filmrecipes:';

  /// Shipped styles are fixed: they cannot be deleted and their favorite
  /// state persists as an id list instead of a full recipe snapshot.
  bool isShipped(UniversalRecipe r) =>
      r.sourceFormat == SourceFormat.builtin ||
      r.id.startsWith(_discoveryIdPrefix);

  static List<UniversalRecipe> _buildDiscoveries() {
    final out = <UniversalRecipe>[];
    for (final s in filmRecipeSources) {
      try {
        final r = RecipeConverter.fromFujiText(s.settings, name: s.name);
        r.id = '$_discoveryIdPrefix${s.id}';
        r.author = 'Justin Gould (film.recipes)';
        r.sourceUrl = s.sourceUrl;
        if (s.description != null && s.description!.isNotEmpty) {
          r.description = s.description;
        }
        out.add(r);
      } catch (_) {
        // Skip a single bad entry rather than losing the whole section.
      }
    }
    return out;
  }

  // ------------------------------------------------------------- errors --
  String? _error;
  String? get error => _error;
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _error = msg;
    notifyListeners();
  }

  // ----------------------------------------------------------- storage --
  static const String _stylesFile = 'styles.json';
  static const String _previewFile = 'preview.jpg';
  static const String _favoritesFile = 'favorites.json';

  final Set<String> _favoriteBuiltinIds = {};

  Future<Directory> _docDir() => _docDirImpl();

  Future<void> load() async {
    // The app-docs directory may be unavailable (e.g. widget tests without a
    // path_provider mock); the app must still start with in-memory defaults.
    try {
      final dir = await _docDir();
      final pv = File('${dir.path}/$_previewFile');
      if (pv.existsSync()) {
        _baseJpeg = pv.readAsBytesSync();
        _hasCustomPreview = true;
      }
      final sf = File('${dir.path}/$_stylesFile');
      if (sf.existsSync()) {
        final list = (jsonDecode(sf.readAsStringSync()) as List)
            .whereType<Map>()
            .map((m) => UniversalRecipe.fromJson(m.cast<String, Object?>()))
            .toList();
        _imports.addAll(list);
      }
      final ff = File('${dir.path}/$_favoritesFile');
      if (ff.existsSync()) {
        _favoriteBuiltinIds.addAll((jsonDecode(ff.readAsStringSync()) as List)
            .whereType<String>());
      }
      for (final b in [..._builtins, ..._discoveries]) {
        b.favorites = _favoriteBuiltinIds.contains(b.id);
      }
    } catch (_) {
      // fall through: start with defaults
    }
    _previewVersion++;
    _loaded = true;
    notifyListeners();
  }

  // ------------------------------------------------------------ actions --

  /// Pick an image from the gallery and use it as the preview base.
  Future<String?> setPreviewImage() async {
    _setBusy('Reading image…');
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return null;
      final src = img.decodeImage(await files.single.readAsBytes());
      if (src == null) {
        _setError('Could not decode that image (HEIC/HEIF is not supported). '
            'Try a JPG or PNG.');
        return null;
      }
      var out = src;
      if (src.width > 1280) {
        final h = (src.height * 1280 / src.width).round();
        out = img.copyResize(src,
            width: 1280, height: h, interpolation: img.Interpolation.linear);
      }
      _baseJpeg = img.encodeJpg(out, quality: 92);
      _hasCustomPreview = true;
      _previewVersion++;
      final dir = await _docDir();
      File('${dir.path}/$_previewFile').writeAsBytesSync(_baseJpeg!);
      notifyListeners();
      return 'Preview image updated.';
    } finally {
      _setBusy(null);
    }
  }

  /// Pick a recipe file (XMP / NP3 / NCP / Fuji text) and import it.
  /// Returns a user-facing summary on success.
  Future<String?> importRecipe() async {
    _setBusy('Importing…');
    try {
      // NOTE: no extension filter here. On Android file_picker maps
      // allowedExtensions to system MIME types, and xmp/np3/ncp have none,
      // which would hide the files we want. We sniff the content ourselves.
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return null;
      final added = <String>[];
      for (final f in files) {
        UniversalRecipe recipe;
        try {
          recipe =
              ImportService.fromBytes(await f.readAsBytes(), name: _stem(f.name));
        } on FormatException catch (e) {
          final msg = e.message;
          _setError(msg.isNotEmpty ? msg : 'Unrecognized recipe file.');
          break;
        }
        recipe.sourceUri = f.path;
        if (!addRecipe(recipe)) continue;
        added.add(recipe.name);
      }
      if (added.isEmpty) return null;
      return added.length == 1
          ? 'Imported “${added.single}” — '
              '${recipeOf(added.single)?.mappingReport?.summary ?? 'native look'}'
          : 'Imported ${added.length} styles.';
    } finally {
      _setBusy(null);
    }
  }

  /// Save a style's NP3 bytes to a location chosen by the user.
  Future<String?> exportNp3(UniversalRecipe recipe) async {
    _setBusy('Preparing .NP3…');
    try {
      final bytes = RecipeConverter.toNp3(recipe);
      final fileName = '${Np3Codec.sanitizeNp3Name(recipe.name)}.NP3';
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save ${recipe.name}',
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
      );
      if (uri == null) return null;
      return uri.toFilePath();
    } finally {
      _setBusy(null);
    }
  }

  /// Create an editable user copy of [recipe].
  ///
  /// Source recipes are immutable (design rule: the original artifact is
  /// never modified), so "edit" always means "work on a copy". The copy is
  /// added to the import library and returned for editing.
  UniversalRecipe duplicateForEditing(UniversalRecipe recipe) {
    var name = recipe.name;
    var n = 2;
    while (allStyles.any((s) => s.name == name)) {
      name = '${recipe.name} ($n)';
      n++;
    }
    final copy = recipe.copyWith(name: name, sourceFormat: SourceFormat.user);
    // The copy is no longer that artifact.
    copy.id = 'user:$name-${DateTime.now().microsecondsSinceEpoch}';
    copy.checksumSha256 = null;
    copy.sourceUri = null;
    _imports.add(copy);
    _persist();
    notifyListeners();
    return copy;
  }

  /// Persist the edited [recipe] (an object in the import library).
  void saveEdited(UniversalRecipe recipe) {
    recipe.modifiedAt = DateTime.now();
    _persist();
    notifyListeners();
  }

  /// Add [recipe] to the import library. Returns false (and sets an error)
  /// when a recipe with the same source checksum is already present.
  bool addRecipe(UniversalRecipe recipe) {
    if (_imports.any((s) =>
        s.checksumSha256 != null &&
        s.checksumSha256 == recipe.checksumSha256)) {
      _setError('Already in your library.');
      return false;
    }
    var name = recipe.name;
    var n = 2;
    while (_imports.any((s) => s.name == name) ||
        [..._builtins, ..._discoveries].any((s) => s.name == name)) {
      name = '${recipe.name} ($n)';
      n++;
    }
    recipe.name = name;
    _imports.add(recipe);
    _persist();
    notifyListeners();
    return true;
  }

  void remove(UniversalRecipe recipe) {
    if (isShipped(recipe)) return;
    _imports.removeWhere((s) => s.id == recipe.id);
    _persist();
    notifyListeners();
  }

  /// Toggle the favorite flag. Import favorites persist with styles.json;
  /// builtin favorites persist as an id list (their recipes are fixed).
  void toggleFavorite(UniversalRecipe recipe) {
    recipe.favorites = !recipe.favorites;
    if (isShipped(recipe)) {
      if (recipe.favorites) {
        _favoriteBuiltinIds.add(recipe.id);
      } else {
        _favoriteBuiltinIds.remove(recipe.id);
      }
      unawaited(_docDir().then((d) {
        File('${d.path}/$_favoritesFile').writeAsStringSync(
            jsonEncode(_favoriteBuiltinIds.toList()));
      }).catchError((Object e) => _setError('Save failed: $e')));
    } else {
      _persist();
    }
    notifyListeners();
  }

  void _persist() {
    unawaited(_docDir().then((d) {
      File('${d.path}/$_stylesFile').writeAsStringSync(
          jsonEncode(_imports.map((s) => s.toJson()).toList()));
    }).catchError((Object e) => _setError('Save failed: $e')));
  }

  void _setBusy(String? msg) {
    _busyMessage = msg;
    notifyListeners();
  }

  UniversalRecipe? recipeOf(String name) {
    for (final s in _imports) {
      if (s.name == name) return s;
    }
    return null;
  }

  static String _stem(String name) {
    final i = name.lastIndexOf('.');
    return i > 0 ? name.substring(0, i) : name;
  }
}