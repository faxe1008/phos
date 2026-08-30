import 'package:flutter/material.dart';

import 'package:phos_core/phos_core.dart';

import '../camera/camera_link.dart';
import '../camera/usb_mtp_transport.dart';
import '../state/app_model.dart';
import '../theme/app_theme.dart';

/// "Send to camera" card: connect over USB-OTG, pick a custom picture
/// control slot (1..9), and register the style directly in the camera via
/// the PTP SetPicCtrlData vendor operation.
class SendToCameraCard extends StatefulWidget {
  const SendToCameraCard({super.key, required this.model, required this.recipe});

  final AppModel model;
  final UniversalRecipe recipe;

  @override
  State<SendToCameraCard> createState() => _SendToCameraCardState();
}

class _SendToCameraCardState extends State<SendToCameraCard> {
  CameraLink get _link => widget.model.cameraLink;

  bool _busy = false;
  String? _error;
  String? _info;
  int _slot = 1;
  List<PicCtrlEntry> _slots = const [];

  bool get _connected => _link.isConnected;
  String? get _connectedLabel => _link.connectedLabel;

  bool get _slotOccupied => _slots.any((s) => s.slot == _slot);

  @override
  void dispose() {
    // Drop a dangling connection if the user leaves mid-session.
    if (_link.isConnected) {
      _link.close().catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final devices = await _link.discover();
      if (!mounted) return;
      if (devices.isEmpty) {
        setState(() {
          _error =
              'No camera found. Connect the camera to the phone with a '
              'USB-OTG cable and make sure it is turned on (any shooting '
              'mode works).';
          return;
        });
      }
      final CameraDevice device;
      if (devices.length == 1) {
        device = devices.single;
      } else {
        final picked = await showDialog<CameraDevice>(
          context: context,
          builder: (ctx) => SimpleDialog(
            backgroundColor: AppTheme.surfaceHigh,
            title: const Text('Choose a camera'),
            children: [
              for (final d in devices)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, d),
                  child: Text(d.label),
                ),
            ],
          ),
        );
        if (!mounted || picked == null) return;
        device = picked;
      }
      await _link.connect(name: device.name, label: device.label);
      if (!mounted) return;
      await _refreshSlots();
      setState(() {
        _info = 'Connected to ${device.label}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshSlots() async {
    if (!_connected) return;
    try {
      final slots = await _link.pictureControls();
      if (!mounted) return;
      setState(() => _slots = slots.where((s) => s.slot != null).toList());
    } catch (_) {
      // Listing slots is best-effort; sending still works without it.
    }
  }

  Future<void> _disconnect() async {
    await _link.close();
    if (!mounted) return;
    setState(() {
      _slots = const [];
      _info = null;
      _error = null;
    });
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await _link.send(widget.recipe, _slot, existing: _slotOccupied);
      if (!mounted) return;
      setState(() => _info = _slotOccupied
          ? 'Replaced slot $_slot with “${widget.recipe.name}”.'
          : '“${widget.recipe.name}” registered in slot $_slot. On the '
              'camera: Menu → Shooting menu → Picture control → Custom '
              'Picture Control $_slot (still photo).');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object e) {
    final s = e.toString();
    final msg = s.replaceFirst('TransportError: ', '').replaceFirst(
        'StateError: ', '').replaceFirst('MtpOperationError: ', '');
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.usb, size: 16, color: AppTheme.seed),
                const SizedBox(width: 8),
                const Text(
                  'Send to camera',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Registers the style as a Custom Picture Control in the '
              'camera over USB-OTG — no SD card needed.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textTertiary, height: 1.5),
            ),
            const SizedBox(height: 14),
            if (_connected) ...[
              Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: AppTheme.seed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectedLabel ?? 'camera connected',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _disconnect,
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var s = 1; s <= 9; s++)
                    ChoiceChip(
                      label: Text(_slots.any((e) => e.slot == s)
                          ? '$s ✓'
                          : '$s'),
                      selected: _slot == s,
                      selectedColor: AppTheme.seed,
                      labelStyle: TextStyle(
                          color: _slot == s
                              ? const Color(0xFF1A1205)
                              : AppTheme.textSecondary,
                          fontSize: 12),
                      onSelected: _busy ? null : (_) => setState(() => _slot = s),
                    ),
                ],
              ),
              if (_slotOccupied)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Slot is occupied — sending replaces it.',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textTertiary),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.seed,
                  foregroundColor: const Color(0xFF1A1205),
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Icons.upload),
                label: Text(
                    _slotOccupied
                        ? 'Replace slot $_slot'
                        : 'Send to slot $_slot'),
                onPressed: _busy ? null : _send,
              ),
            ] else
              OutlinedButton.icon(
                icon: const Icon(Icons.cameraswitch_outlined),
                label: const Text('Connect camera'),
                onPressed: _busy ? null : _connect,
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Talking to the camera…',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textTertiary)),
                  ],
                ),
              ),
            if (_info != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _info!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.5),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFF6B57),
                      height: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}