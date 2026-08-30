/// How a source field was handled when converting to the target.
///
/// The brief's key product principle: never silently claim a conversion is
/// exact when the source and target pipelines differ. Every converted field
/// carries one of these statuses.
enum MappingStatus {
  /// Same semantics, same range. 1:1 copy.
  exact,

  /// Same semantics, range rescaled to the target.
  scaled,

  /// Approximation: semantics only roughly overlap.
  approximated,

  /// Mapped, but the source value was clamped to the target range.
  clamped,

  /// No target equivalent; value kept in source metadata only.
  unsupported,

  /// Source field was superseded by a higher-priority source field
  /// (e.g. a custom tone curve overriding the quick-adjust tonal sliders).
  superseded,

  /// Field intentionally left untouched on the target (was already at default).
  ignored,
}

extension MappingStatusX on MappingStatus {
  String get label => switch (this) {
        MappingStatus.exact => 'Exact',
        MappingStatus.scaled => 'Scaled',
        MappingStatus.approximated => 'Approximated',
        MappingStatus.clamped => 'Clamped',
        MappingStatus.unsupported => 'Unsupported',
        MappingStatus.superseded => 'Superseded',
        MappingStatus.ignored => 'Ignored',
      };
}

/// One row of a conversion report.
class FieldMapping {
  const FieldMapping({
    required this.sourceField,
    required this.targetField,
    required this.sourceValue,
    required this.targetValue,
    required this.status,
    this.note,
  });

  /// Dotted path in the source model, e.g. `xmp.contrast` or `fuji.highlight`.
  final String sourceField;

  /// Dotted path in the target model, e.g. `tone.contrast`. Empty when the
  /// field has no target.
  final String targetField;

  final String? sourceValue;
  final String? targetValue;
  final MappingStatus status;

  /// Human-readable explanation, e.g. "Fuji -4..+4 scaled x25 to Nikon -100..+100".
  final String? note;

  bool get isLossy =>
      status == MappingStatus.approximated ||
      status == MappingStatus.clamped ||
      status == MappingStatus.unsupported;

  Map<String, Object?> toJson() => {
        'source': sourceField,
        'target': targetField,
        'sourceValue': sourceValue,
        'targetValue': targetValue,
        'status': status.name,
        if (note != null) 'note': note,
      };

  factory FieldMapping.fromJson(Map<String, Object?> j) => FieldMapping(
        sourceField: j['source'] as String,
        targetField: j['target'] as String? ?? '',
        sourceValue: j['sourceValue'] as String?,
        targetValue: j['targetValue'] as String?,
        status: MappingStatus.values.byName(j['status'] as String? ?? 'ignored'),
        note: j['note'] as String?,
      );

  @override
  String toString() =>
      '$sourceField -> ${targetField.isEmpty ? '(none)' : targetField}: $sourceValue => $targetValue [$status$note]';
}

/// Overall fidelity of a conversion.
enum ConversionStatus { exact, high, approximation, lossy }

/// The complete, per-field record of a conversion run.
class MappingReport {
  MappingReport({required this.sourceFormat, required this.target, required this.fields, required this.mappingVersion});

  final String sourceFormat;
  final String target;
  final List<FieldMapping> fields;

  /// Version tag of the mapping formulas, e.g. "xmp->np3:1". Bump whenever a
  /// formula changes so old recipes can be re-converted deterministically.
  final String mappingVersion;

  int get mappedCount => fields
      .where((f) =>
          f.status == MappingStatus.exact ||
          f.status == MappingStatus.scaled ||
          f.status == MappingStatus.approximated ||
          f.status == MappingStatus.clamped)
      .length;

  int get unsupportedCount => fields.where((f) => f.status == MappingStatus.unsupported).length;

  int get clampedCount => fields.where((f) => f.status == MappingStatus.clamped).length;

  int get approximatedCount => fields.where((f) => f.status == MappingStatus.approximated).length;

  ConversionStatus get overall {
    if (fields.every((f) => f.status == MappingStatus.exact || f.status == MappingStatus.ignored)) {
      return ConversionStatus.exact;
    }
    if (unsupportedCount == 0 && approximatedCount == 0 && clampedCount == 0) {
      return ConversionStatus.high;
    }
    return ConversionStatus.approximation;
  }

  /// A short, user-facing summary line.
  String get summary {
    final status = overall;
    final head = switch (status) {
      ConversionStatus.exact => 'EXACT',
      ConversionStatus.high => 'HIGH-CONFIDENCE',
      ConversionStatus.approximation => 'APPROXIMATION',
      ConversionStatus.lossy => 'LOSSY',
    };
    return '$head: $mappedCount mapped, $unsupportedCount unsupported, '
        '$approximatedCount approximated, $clampedCount clamped';
  }

  Map<String, Object?> toJson() => {
        'sourceFormat': sourceFormat,
        'target': target,
        'mappingVersion': mappingVersion,
        'fields': fields.map((f) => f.toJson()).toList(),
      };

  factory MappingReport.fromJson(Map<String, Object?> j) => MappingReport(
        sourceFormat: j['sourceFormat'] as String? ?? 'unknown',
        target: j['target'] as String? ?? 'nikon',
        mappingVersion: j['mappingVersion'] as String? ?? '1',
        fields: (j['fields'] as List? ?? const [])
            .map((e) => FieldMapping.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
      );
}