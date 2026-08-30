import 'package:phos_core/phos_core.dart';

import 'usb_mtp_transport.dart';

/// High-level "send a recipe to the camera" service.
///
/// Owns the [MtpSession] over a [UsbTransport] (Android USB host by
/// default, injectable for tests) and turns [UniversalRecipe]s into
/// camera-side picture controls registered in a custom slot.
class CameraLink {
  CameraLink({UsbTransport? transport}) : _injected = transport;

  final UsbTransport? _injected;
  MtpSession? _session;
  String? _label;

  bool get isConnected => _session != null && _session!.isOpen;
  String? get connectedLabel => _label;

  /// Cameras with an MTP interface currently on the USB bus.
  Future<List<CameraDevice>> discover() {
    if (_injected != null) return Future.value(const []);
    return UsbMtpTransport.discover();
  }

  /// Request permission, open the device and start a PTP session.
  Future<void> connect({required String name, required String label}) async {
    if (isConnected) return;
    final t = _injected ?? UsbMtpTransport();
    if (_injected == null) {
      final granted = await UsbMtpTransport.requestPermission(name);
      if (!granted) {
        throw StateError('USB permission was not granted');
      }
      await UsbMtpTransport.openDevice(name);
    }
    final s = MtpSession(t);
    await s.open();
    _session = s;
    _label = label;
  }

  /// Picture controls currently registered in the camera's custom slots.
  Future<List<PicCtrlEntry>> pictureControls() {
    final s = _session;
    if (s == null || !s.isOpen) {
      throw StateError('no camera connected');
    }
    return s.pictureControls();
  }

  /// Register [recipe]'s Nikon projection as a new custom picture control
  /// in slot [slot] (1..9). With [existing] the slot's current control is
  /// overwritten in place.
  Future<void> send(
    UniversalRecipe recipe,
    int slot, {
    bool existing = false,
  }) async {
    final s = _session;
    if (s == null || !s.isOpen) {
      throw StateError('no camera connected');
    }
    final nikon = recipe.nikon;
    final ds = PicCtrlDataSet.fromNikon(
      nikon,
      baseCode: PicCtrlDataSet.baseCodeFor(nikon.baseProfileHint),
    );
    await s.registerPictureControl(slot, ds, existing: existing);
  }

  Future<void> close() async {
    final s = _session;
    _session = null;
    _label = null;
    if (s != null) {
      try {
        await s.close();
      } finally {
        s.dispose();
      }
    }
  }
}