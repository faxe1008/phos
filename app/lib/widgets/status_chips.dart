import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../theme/app_theme.dart';

/// Color-coded chip for a [MappingStatus].
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final MappingStatus status;

  static Color color(MappingStatus s) => switch (s) {
        MappingStatus.exact => const Color(0xFF4CAF7D),
        MappingStatus.scaled => const Color(0xFF5CA8FF),
        MappingStatus.approximated => const Color(0xFFE8A33D),
        MappingStatus.clamped => const Color(0xFFE8703D),
        MappingStatus.unsupported => const Color(0xFF8A8A99),
        MappingStatus.superseded => const Color(0xFFB57BFF),
        MappingStatus.ignored => const Color(0xFF66666F),
      };

  @override
  Widget build(BuildContext context) {
    final c = color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

/// Overall conversion-quality badge for a recipe.
class OverallChip extends StatelessWidget {
  const OverallChip({super.key, required this.recipe});

  final UniversalRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final report = recipe.mappingReport;
    String label;
    Color color;
    if (report == null) {
      label = 'Native';
      color = AppTheme.seed;
    } else {
      final o = report.overall;
      label = switch (o) {
        ConversionStatus.exact => 'Exact',
        ConversionStatus.high => 'High',
        ConversionStatus.approximation => 'Approx',
        ConversionStatus.lossy => 'Lossy',
      };
      color = switch (o) {
        ConversionStatus.exact => const Color(0xFF4CAF7D),
        ConversionStatus.high => const Color(0xFF5CA8FF),
        ConversionStatus.approximation => const Color(0xFFE8A33D),
        ConversionStatus.lossy => const Color(0xFFE8703D),
      };
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Small source-format badge (Catalog / Lightroom / Fuji / NP3).
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.recipe});

  final UniversalRecipe recipe;

  static (String, IconData) of(UniversalRecipe r) => switch (r.sourceFormat) {
        SourceFormat.xmp => ('Lightroom', Icons.photo_size_select_small),
        SourceFormat.fujiText => ('Fuji', Icons.filter_none),
        SourceFormat.np3 => ('NP3', Icons.memory),
        SourceFormat.builtin => ('Catalog', Icons.auto_awesome),
        _ => (r.sourceFormat.label, Icons.file_open),
      };

  @override
  Widget build(BuildContext context) {
    final (label, icon) = of(recipe);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
      ],
    );
  }
}