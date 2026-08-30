import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../preview/preview_service.dart';
import '../theme/app_theme.dart';

/// Renders the preview of [params] applied to [baseJpeg] via the shared
/// [service] (isolated + cached). Re-renders when any input changes.
class PreviewBox extends StatefulWidget {
  const PreviewBox({
    super.key,
    required this.service,
    required this.baseJpeg,
    required this.params,
    required this.width,
    required this.version,
    this.borderRadius = 16,
  });

  final PreviewService service;
  final Uint8List baseJpeg;
  final NikonParams params;
  final int width;
  final int version;
  final double borderRadius;

  @override
  State<PreviewBox> createState() => _PreviewBoxState();
}

class _PreviewBoxState extends State<PreviewBox> {
  String? _key;
  Uint8List? _bytes;
  String? _error;

  String get _currentKey =>
      '${widget.version}:${widget.width}:${jsonEncode(widget.params.toJson())}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PreviewBox old) {
    super.didUpdateWidget(old);
    if (_currentKey != _key) _load();
  }

  Future<void> _load() async {
    final key = _currentKey;
    _key = key;
    setState(() {
      _bytes = null;
      _error = null;
    });
    try {
      final bytes = await widget.service.renderThumbnail(
        baseJpeg: widget.baseJpeg,
        params: widget.params,
        width: widget.width,
        version: widget.version,
      );
      if (!mounted || key != _currentKey) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      if (!mounted || key != _currentKey) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: _bytes != null
          ? Image.memory(_bytes!, fit: BoxFit.cover)
          : Container(
              color: AppTheme.surfaceHigh,
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textTertiary),
                            textAlign: TextAlign.center),
                      )
                    : const Icon(Icons.photo_outlined,
                        size: 22, color: AppTheme.textTertiary),
              ),
            ),
    );
  }
}