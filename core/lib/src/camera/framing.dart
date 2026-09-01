import 'dart:typed_data';

/// PTP/MTP "Generic Container" framing (Z50II MTP spec section 5.1, which
/// conforms to the MTP/PTP specification).
///
/// Every container is:
///
/// ```
/// offset 0  u32  ContainerLength  (total bytes of this container,
///                                   including this header, little endian)
/// offset 4  u16  ContainerType    1 command, 2 data, 3 response, 4 event
/// offset 6  u16  Code             OperationCode / ResponseCode / EventCode
/// offset 8  u32  TransactionID
/// offset 12 ..  Payload
/// ```
class PtpContainer {
  const PtpContainer({
    required this.type,
    required this.code,
    required this.transactionId,
    required this.payload,
  });

  static const int typeCommand = 0x0001;
  static const int typeData = 0x0002;
  static const int typeResponse = 0x0003;
  static const int typeEvent = 0x0004;

  static const int headerSize = 12;

  final int type;
  final int code;
  final int transactionId;
  final List<int> payload;

  int get byteLength => headerSize + payload.length;

  Uint8List toBytes() {
    final out = Uint8List(byteLength);
    _le32(out, 0, byteLength);
    _le16(out, 4, type);
    _le16(out, 6, code);
    _le32(out, 8, transactionId);
    out.setRange(headerSize, byteLength, payload);
    return out;
  }

  /// Parse one container from [bytes]. [bytes] must start at the container's
  /// first byte; extra trailing bytes (e.g. a following event) are ignored.
  static PtpContainer parse(List<int> bytes) {
    if (bytes.length < headerSize) {
      throw FormatException('truncated PTP container: ${bytes.length} bytes');
    }
    final len = _readLe32(bytes, 0);
    final type = _readLe16(bytes, 4);
    final code = _readLe16(bytes, 6);
    final tx = _readLe32(bytes, 8);
    if (len < headerSize || len > bytes.length) {
      throw FormatException(
          'implausible container length $len from ${bytes.length} bytes');
    }
    return PtpContainer(
      type: type,
      code: code,
      transactionId: tx,
      payload: Uint8List.fromList(bytes.sublist(headerSize, len)),
    );
  }

  @override
  String toString() =>
      'PtpContainer(type=$type, code=0x${code.toRadixString(16)}, '
      'tx=$transactionId, ${payload.length}B payload)';
}

/// A command block: operation code + zero to three u32 parameters.
class PtpCommand {
  const PtpCommand({
    required this.operation,
    required this.transactionId,
    this.param1,
    this.param2,
    this.param3,
  });

  final int operation;
  final int transactionId;
  final int? param1;
  final int? param2;
  final int? param3;

  PtpContainer toContainer() {
    final params = [param1, param2, param3];
    final count = params.lastIndexWhere((value) => value != null) + 1;
    final p = Uint8List(count * 4);
    for (var i = 0; i < count; i++) {
      _le32(p, i * 4, params[i]!);
    }
    return PtpContainer(
      type: PtpContainer.typeCommand,
      code: operation,
      transactionId: transactionId,
      payload: p,
    );
  }
}

/// A response block: response code + two u32 parameters.
class PtpResponse {
  const PtpResponse({
    required this.code,
    required this.transactionId,
    required this.param1,
    required this.param2,
  });

  final int code;
  final int transactionId;
  final int param1;
  final int param2;

  bool get ok => code == 0x5000;

  static PtpResponse parse(PtpContainer c) {
    if (c.type != PtpContainer.typeResponse) {
      throw FormatException('not a response container: $c');
    }
    if (c.payload.length < 8) {
      throw FormatException('response payload too short: ${c.payload.length}');
    }
    return PtpResponse(
      code: c.code,
      transactionId: c.transactionId,
      param1: _readLe32(c.payload, 0),
      param2: _readLe32(c.payload, 4),
    );
  }

  @override
  String toString() =>
      'PtpResponse(0x${code.toRadixString(16)}, tx=$transactionId, '
      'p1=$param1, p2=$param2)';
}

// ---------------------------------------------------------------- helpers --

void _le16(List<int> b, int off, int v) {
  b[off] = v & 0xff;
  b[off + 1] = (v >> 8) & 0xff;
}

void _le32(List<int> b, int off, int v) {
  b[off] = v & 0xff;
  b[off + 1] = (v >> 8) & 0xff;
  b[off + 2] = (v >> 16) & 0xff;
  b[off + 3] = (v >> 24) & 0xff;
}

int _readLe16(List<int> b, int off) => b[off] | (b[off + 1] << 8);

int _readLe32(List<int> b, int off) =>
    b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24);
