import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../theme/app_theme.dart';
import 'status_chips.dart';

/// Per-field fidelity report for a converted recipe.
class FidelityReport extends StatelessWidget {
  const FidelityReport({super.key, required this.report});

  final MappingReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report.summary.toUpperCase(),
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
        const SizedBox(height: 2),
        Text(
          'mapping ${report.mappingVersion} · target ${report.target}',
          style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
        ),
        const SizedBox(height: 12),
        for (final f in report.fields) _Row(f: f),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.f});

  final FieldMapping f;

  @override
  Widget build(BuildContext context) {
    final dim = f.status == MappingStatus.ignored ||
        f.status == MappingStatus.unsupported;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  f.targetField.isEmpty ? f.sourceField : '${f.sourceField} → ${f.targetField}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dim ? AppTheme.textTertiary : AppTheme.textSecondary),
                ),
              ),
              StatusChip(status: f.status),
            ],
          ),
          if ((f.sourceValue?.isNotEmpty ?? false) ||
              (f.targetValue?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(
                '${f.sourceValue ?? ''}${(f.sourceValue?.isNotEmpty ?? false) && (f.targetValue?.isNotEmpty ?? false) ? '  ⇒  ' : ''}${f.targetValue ?? ''}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ),
          if (f.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(
                f.note!,
                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}