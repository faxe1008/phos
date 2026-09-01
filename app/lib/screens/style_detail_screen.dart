import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:phos_core/phos_core.dart';

import '../state/app_model.dart';
import '../theme/app_theme.dart';
import '../widgets/compare_preview_box.dart';
import '../widgets/fidelity_report.dart';
import 'style_editor_screen.dart';
import '../widgets/send_to_camera_card.dart';
import '../widgets/status_chips.dart';

/// Full-screen view of one style: big preview, fidelity report, actions.
class StyleDetailScreen extends StatefulWidget {
  const StyleDetailScreen({
    super.key,
    required this.model,
    required this.recipe,
    this.styles,
    this.initialIndex = 0,
  });

  final AppModel model;
  final UniversalRecipe recipe;
  final List<UniversalRecipe>? styles;
  final int initialIndex;

  @override
  State<StyleDetailScreen> createState() => _StyleDetailScreenState();
}

class _StyleDetailScreenState extends State<StyleDetailScreen> {
  late final PageController _pages;
  late int _index;

  List<UniversalRecipe> get _styles => widget.styles ?? [widget.recipe];
  UniversalRecipe get _recipe => _styles[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _styles.length - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final m = widget.model;
    final path = await m.exportNp3(_recipe);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path == null ? 'Cancelled.' : 'Saved to $path')),
    );
  }

  /// User-created recipes are edited in place. Source artifacts remain
  /// immutable, so built-ins and imports continue through the copy flow.
  Future<void> _edit() async {
    final m = widget.model;
    final editInPlace = _recipe.sourceFormat == SourceFormat.user;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text(editInPlace ? 'Edit style?' : 'Edit a copy?'),
        content: Text(
          editInPlace
              ? 'This style will be updated in your library.'
              : 'Source styles are immutable. Phos will create an editable copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(editInPlace ? 'Edit' : 'Create copy'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    final copy = editInPlace ? _recipe : m.duplicateForEditing(_recipe);
    if (!mounted) return;
    final saved = editInPlace
        ? await Navigator.of(context).push<UniversalRecipe>(
            MaterialPageRoute<UniversalRecipe>(
              builder: (_) => StyleEditorScreen(model: m, recipe: copy),
            ),
          )
        : await Navigator.of(context).pushReplacement<UniversalRecipe, void>(
            MaterialPageRoute<UniversalRecipe>(
              builder: (_) => StyleEditorScreen(model: m, recipe: copy),
            ),
          );
    if (saved == null && !editInPlace) {
      // Cancelled: drop the unused copy.
      m.remove(copy);
    } else if (saved != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StyleDetailScreen(model: m, recipe: saved),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: const Text('Delete this style?'),
        content: Text('“${_recipe.name}” will be removed from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF6B57)),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.model.remove(_recipe);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _busy(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.seed),
          const SizedBox(height: 14),
          Text(msg, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        if (m.busyMessage != null) return _busy(m.busyMessage!);
        return Scaffold(
          appBar: AppBar(
            title: Text(_recipe.name),
            leading: _styles.length > 1
                ? IconButton(
                    tooltip: 'Back to library',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Duplicate and edit',
                icon: const Icon(Icons.tune),
                onPressed: _edit,
              ),
              IconButton(
                tooltip: _recipe.favorites
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                icon: Icon(
                  _recipe.favorites ? Icons.star : Icons.star_border,
                  color: _recipe.favorites ? AppTheme.seed : null,
                ),
                onPressed: () => m.toggleFavorite(_recipe),
              ),
              if (_recipe.sourceFormat != SourceFormat.builtin &&
                  !m.isShipped(_recipe))
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFFF6B57),
                  ),
                  onPressed: _delete,
                ),
            ],
          ),
          body: PageView.builder(
            controller: _pages,
            itemCount: _styles.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => _detailBody(_styles[index], m),
          ),
        );
      },
    );
  }

  Widget _detailBody(UniversalRecipe r, AppModel m) {
    final isImport = r.sourceFormat != SourceFormat.builtin;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        ComparePreviewBox(
          service: m.preview,
          baseJpeg: m.baseJpeg,
          params: r.nikon,
          width: 840,
          version: m.previewVersion,
          borderRadius: 20,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Hold the preview to compare with the original',
              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SourceBadge(recipe: r),
            const SizedBox(width: 10),
            OverallChip(recipe: r),
            if (r.sourceUrl != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(r.sourceUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.open_in_new,
                          size: 12,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            'source',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if ((r.description?.isNotEmpty ?? false) ||
            (r.author?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          if (r.description?.isNotEmpty ?? false)
            Text(
              r.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          if (r.author?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'by ${r.author}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
        ],
        if (r.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in r.tags)
                  Chip(label: Text(t), visualDensity: VisualDensity.compact),
              ],
            ),
          ),

        if (isImport && r.mappingReport != null) ...[
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FidelityReport(report: r.mappingReport!),
            ),
          ),
        ],

        const SizedBox(height: 20),
        SendToCameraCard(model: m, recipe: r),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.seed,
            foregroundColor: const Color(0xFF1A1205),
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.download),
          label: const Text('Save .NP3 to device'),
          onPressed: _export,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Icon(
                      Icons.cameraswitch_outlined,
                      size: 16,
                      color: AppTheme.seed,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Using it on the Z50II',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  '1. Tap “Save .NP3 to device” and choose a location.\n'
                  '2. Copy the .NP3 file to the camera’s SD card into the CustomLUT folder.\n'
                  '3. On the camera: Menu → Setup → Custom LUT → pick the file.\n'
                  '4. Select it from the Custom LUT list in your shooting menu.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
