import 'framing.dart';

/// Raw byte transport to a camera speaking PTP over its bulk USB endpoints.
///
/// The protocol layer (see `MtpSession`) only needs "send a container, get a
/// container", so transports (Android USB host, desktop USB, a loopback fake
/// for tests) implement this interface.
abstract interface class UsbTransport {
  /// Write [bytes] to the camera (bulk OUT).
  Future<void> write(List<int> bytes);

  /// Read one complete container from the camera (bulk IN): the first 12
  /// bytes are the header; [ContainerLength] tells how many more to fetch.
  ///
  /// Must time out and throw a [TransportTimeout] when nothing arrives.
  Future<PtpContainer> readContainer({Duration timeout = const Duration(seconds: 10)});

  /// Recover from a protocol desync (clear endpoint halts, or reset the
  /// device). After a call, a fresh OpenSession is required.
  Future<void> recover();

  void dispose();
}

/// A transport read or write did not complete in time.
class TransportTimeout implements Exception {
  const TransportTimeout(this.where);

  final String where;

  @override
  String toString() => 'transport timeout in $where';
}

/// A USB-level failure (device gone, transfer failed, ...).
class TransportError implements Exception {
  const TransportError(this.message);

  final String message;

  @override
  String toString() => 'transport error: $message';
}