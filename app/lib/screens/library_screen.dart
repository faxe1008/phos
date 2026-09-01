import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../state/app_model.dart';
import '../theme/app_theme.dart';
import 'style_detail_screen.dart';
import '../widgets/style_card.dart';

/// Home screen: the style library with live previews.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.model});

  final AppModel model;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final msg = await widget.model.importRecipe();
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _pickPreview() async {
    final msg = await widget.model.setPreviewImage();
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  List<UniversalRecipe> _filter(List<UniversalRecipe> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.tags.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.seed, Color(0xFFE8590C)],
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Phos'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Change preview image',
            icon: const Icon(Icons.image_outlined),
            onPressed: m.loaded ? _pickPreview : null,
          ),
          IconButton(
            tooltip: 'Import recipe (XMP / Fuji / NP3)',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: m.loaded ? _import : null,
          ),
        ],
      ),
      floatingActionButton: m.loaded
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.surfaceHigh,
              foregroundColor: AppTheme.textPrimary,
              icon: const Icon(Icons.add, color: AppTheme.seed),
              label: const Text('Import style'),
              onPressed: _import,
            )
          : null,
      body: !m.loaded
          ? const _LoadingView()
          : ListenableBuilder(
              listenable: m,
              builder: (context, _) {
                if (m.busyMessage != null) {
                  return _busy(m.busyMessage!);
                }
                final favs = _filter(m.favorites);
                final builtins = _filter(m.builtins);
                final disc = _filter(m.discoveries);
                final imports = _filter(m.imports);
                final nothing =
                    builtins.isEmpty &&
                    disc.isEmpty &&
                    imports.isEmpty &&
                    favs.isEmpty;
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _topBanners()),
                    SliverToBoxAdapter(child: _searchBox()),
                    if (favs.isNotEmpty) ..._section('Favorites', favs),
                    if (builtins.isNotEmpty) ..._section('Catalog', builtins),
                    if (disc.isNotEmpty) ..._section('From film.recipes', disc),
                    if (imports.isNotEmpty) ..._section('My imports', imports),
                    if (nothing) SliverToBoxAdapter(child: _noResults()),
                  ],
                );
              },
            ),
    );
  }

  Widget _busy(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.seed),
            const SizedBox(height: 16),
            Text(msg, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.search, size: 18, color: AppTheme.textTertiary),
            ),
            Expanded(
              child: TextField(
                controller: _search,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search styles…',
                  hintStyle: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 13,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AppTheme.textTertiary,
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topBanners() {
    final m = widget.model;
    return Column(
      children: [
        if (m.error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF3A1D1D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE8590C).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    m.error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFFB4A2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: const Color(0xFFFFB4A2),
                  onPressed: m.clearError,
                ),
              ],
            ),
          ),
        if (!m.hasCustomPreview)
          GestureDetector(
            onTap: _pickPreview,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 18,
                    color: AppTheme.seed,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Previewing on a default test card — tap to use your own photo',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _section(String title, List<UniversalRecipe> styles) => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 16, 10),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppTheme.textTertiary,
          ),
        ),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final r = styles[i];
          return StyleCard(
            recipe: r,
            service: widget.model.preview,
            baseJpeg: widget.model.baseJpeg,
            version: widget.model.previewVersion,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StyleDetailScreen(
                  model: widget.model,
                  recipe: r,
                  styles: styles,
                  initialIndex: i,
                ),
              ),
            ),
          );
        }, childCount: styles.length),
      ),
    ),
  ];

  Widget _noResults() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_off_outlined, color: AppTheme.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _query.isEmpty
                  ? 'Nothing here yet — import your first style.'
                  : 'No styles match “$_query”.',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.seed),
            SizedBox(height: 16),
            Text('Loading your library…'),
          ],
        ),
      ),
    );
  }
}
