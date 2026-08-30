import 'package:flutter/services.dart';
import 'package:phos_core/phos_core.dart';

/// A camera discovered on the USB bus with an MTP interface.
class CameraDevice {
  const CameraDevice({
    required this.name,
    required this.label,
    this.granted = false,
  });

  /// UsbManager device name (stable while the device is attached).
  final String name;

  /// "Nikon CORPORATION Z 50_II" style label.
  final String label;

  /// Whether USB permission was already granted.
  final bool granted;

  @override
  String toString() => label;
}

/// [UsbTransport] backed by the Android USB host stack, via the
/// MtpUsbPlugin MethodChannel.
///
/// The plugin moves raw bytes between Dart and the camera's bulk
/// endpoints; PTP framing stays in [PtpContainer].
class UsbMtpTransport implements UsbTransport {
  static const MethodChannel _channel = MethodChannel('phos.mtp_usb');

  /// Cameras with an MTP interface currently on the USB bus.
  static Future<List<CameraDevice>> discover() async {
    final list =
        await _channel.invokeMethod<List>('listDevices') ?? const <List>[];
    return list
        .map(
          (e) => CameraDevice(
            name: (e as Map)['name'] as String,
            label: e['label'] as String,
            granted: e['granted'] as bool? ?? false,
          ),
        )
        .toList();
  }

  /// Ask the system for USB access to [name]; resolves true when granted
  /// (or already granted).
  static Future<bool> requestPermission(String name) async {
    final r = await _channel.invokeMethod<bool>('requestPermission', {
      'name': name,
    });
    return r ?? false;
  }

  /// Open the device and claim its MTP interface.
  static Future<void> openDevice(String name) async {
    try {
      await _channel.invokeMethod<void>('open', {'name': name});
    } on PlatformException catch (e) {
      throw TransportError(e.message ?? e.toString());
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    try {
      await _channel.invokeMethod<void>('write', {'bytes': bytes});
    } on PlatformException catch (e) {
      throw TransportError(e.message ?? e.toString());
    }
  }

  @override
  Future<PtpContainer> readContainer({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final header =
          await _channel.invokeMethod<List<int>>('read', {'count': 12});
      if (header == null || header.length < 12) {
        throw TransportError('short header read (${header?.length})');
      }
      final len = header[0] |
          (header[1] << 8) |
          (header[2] << 16) |
          (header[3] << 24);
      final rest = len - 12;
      if (rest < 0 || rest > 1 << 20) {
        throw TransportError('implausible container length $len');
      }
      final payload = rest > 0
          ? await _channel.invokeMethod<List<int>>('read', {
              'count': rest,
            }) ??
              <int>[]
          : <int>[];
      return PtpContainer.parse([...header, ...payload]);
    } on PlatformException catch (e) {
      throw TransportError(e.message ?? e.toString());
    }
  }

  @override
  Future<void> recover() async {
    try {
      await _channel.invokeMethod<void>('recover');
    } on PlatformException catch (e) {
      throw TransportError(e.message ?? e.toString());
    }
  }

  @override
  void dispose() {
    _channel.invokeMethod<void>('close').catchError((_) {});
  }
}