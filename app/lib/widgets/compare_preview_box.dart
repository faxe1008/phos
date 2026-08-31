import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../preview/preview_service.dart';
import '../theme/app_theme.dart';
import 'preview_box.dart';

/// [PreviewBox] with hold-to-compare: while the image is pressed the
/// unmodified base image is shown instead of the styled render, so a style
/// can be judged against the original.
class ComparePreviewBox extends StatefulWidget {
  const ComparePreviewBox({
    super.key,
    required this.service,
    required this.baseJpeg,
    required this.params,
    required this.width,
    required this.version,
    this.borderRadius = 16,
    this.onCompareChanged,
  });

  final PreviewService service;
  final Uint8List baseJpeg;
  final NikonParams params;
  final int width;
  final int version;
  final double borderRadius;

  /// Notified with `true` while the original is shown, `false` when the
  /// styled render comes back.
  final ValueChanged<bool>? onCompareChanged;

  @override
  State<ComparePreviewBox> createState() => _ComparePreviewBoxState();
}

class _ComparePreviewBoxState extends State<ComparePreviewBox> {
  bool _comparing = false;
  Uint8List? _plain;
  bool _plainLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPlain();
  }

  @override
  void didUpdateWidget(ComparePreviewBox old) {
    super.didUpdateWidget(old);
    if (old.baseJpeg != widget.baseJpeg ||
        old.width != widget.width ||
        old.version != widget.version) {
      _loadPlain();
    }
  }

  Future<void> _loadPlain() async {
    if (_plainLoading) return;
    _plainLoading = true;
    try {
      final bytes = await widget.service.renderPlain(
        baseJpeg: widget.baseJpeg,
        width: widget.width,
        version: widget.version,
      );
      if (!mounted) return;
      setState(() => _plain = bytes);
    } catch (_) {
      // Best effort: comparison simply stays unavailable.
    } finally {
      if (mounted) setState(() => _plainLoading = false);
    }
  }

  void _setComparing(bool v) {
    if (_comparing == v) return;
    setState(() => _comparing = v);
    widget.onCompareChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _setComparing(true),
      onLongPressEnd: (_) => _setComparing(false),
      onLongPressCancel: () => _setComparing(false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        // Fixed 4:3 ratio so the box has a definite size both in a
        // ListView (unbounded height — StackFit.expand alone would throw)
        // and in tests (mock image decoders report 1x1).
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PreviewBox(
                service: widget.service,
                baseJpeg: widget.baseJpeg,
                params: widget.params,
                width: widget.width,
                version: widget.version,
                borderRadius: widget.borderRadius,
              ),
              if (_comparing && _plain != null)
                Image.memory(_plain!, fit: BoxFit.cover),
              if (_comparing && _plain == null)
                Positioned.fill(
                  child: Container(
                    color: AppTheme.surfaceHigh,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.seed),
                      ),
                    ),
                  ),
                ),
              if (_comparing)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _chip('Original'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC14120E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo, size: 12, color: AppTheme.textPrimary),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}