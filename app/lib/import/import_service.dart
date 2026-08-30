import 'dart:io';

import 'package:phos_core/phos_core.dart';

/// Turns a picked file into a [UniversalRecipe], sniffing the format from
/// its magic bytes / content rather than trusting the extension.
abstract final class ImportService {
  static const List<int> _np3Magic = [0x4e, 0x43, 0x50, 0x00];

  static UniversalRecipe fromFile(File file, {String? name}) {
    final bytes = file.readAsBytesSync();
    return fromBytes(bytes, name: name ?? _stem(file.path));
  }

  static bool _isNp3(List<int> bytes) {
    for (var i = 0; i < _np3Magic.length; i++) {
      if (i >= bytes.length || bytes[i] != _np3Magic[i]) return false;
    }
    return true;
  }

  static UniversalRecipe fromBytes(List<int> bytes, {String? name}) {
    if (_isNp3(bytes)) {
      return RecipeConverter.fromNp3(bytes, name: name);
    }
    final text = String.fromCharCodes(
        bytes.where((b) => b >= 0x20 && b < 0x7f || b == 0x0a || b == 0x0d));
    if (text.contains('xpacket') ||
        text.contains('rdf:RDF') ||
        text.contains('camera-raw-settings')) {
      return RecipeConverter.fromXmp(bytes, name: name);
    }
    final fuji = FujiRecipeParser.parse(text);
    if (fuji.filmSimulation != null ||
        fuji.highlightTone != null ||
        fuji.shadowTone != null ||
        fuji.color != null) {
      return RecipeConverter.fromFujiText(text, name: name);
    }
    throw const FormatException(
        'Could not recognize this file as NP3, XMP, or a Fuji recipe');
  }

  static String _stem(String path) {
    final name = path.split(RegExp(r'[\\/]+')).last;
    final i = name.lastIndexOf('.');
    return i > 0 ? name.substring(0, i) : name;
  }
}