import 'dart:typed_data';

import 'framing.dart';
import 'ops.dart';
import 'pic_ctrl.dart';
import 'transport.dart';

/// A PTP session with a Nikon camera, speaking the operations from the
/// Z50II MTP spec that Phos needs: session management plus the vendor
/// Picture Control set (spec 6.2.9).
///
/// Phase discipline (spec 5.3): command block, then — for host→camera
/// operations — a data block, then — for camera→host operations — a data
/// block, then the response block. One transaction at a time.
class MtpSession {
  MtpSession(this._transport);

  final UsbTransport _transport;

  int _transactionId = 1; // spec: first command after OpenSession is 1
  int _sessionHandle = 0;
  bool _open = false;

  bool get isOpen => _open;
  int get sessionHandle => _sessionHandle;

  /// Talk to the camera outside a session (GetDeviceInfo is the only
  /// operation allowed there) and then open one.
  Future<void> open() async {
    if (_open) return;
    // Readiness check + device info (allowed outside a session).
    await _request(
      PtpOps.getDeviceInfo,
      expectData: true,
    );
    // OpenSession: the spec fixes its TransactionID at 0.
    final (response, _) = await _sendAndRespond(
      PtpCommand(
        operation: PtpOps.openSession,
        transactionId: 0,
        param1: 0x0001, // SessionID, must be non-zero
      ),
    );
    _check(response);
    _sessionHandle = response.param1;
    _transactionId = 1;
    _open = true;
  }

  Future<void> close() async {
    if (!_open) return;
    try {
      final (response, _) = await _sendAndRespond(
        PtpCommand(
          operation: PtpOps.closeSession,
          transactionId: _nextTx(),
          param1: _sessionHandle,
        ),
      );
      _check(response);
    } finally {
      _open = false;
      _sessionHandle = 0;
    }
  }

  /// All registered picture controls (custom slots that have content).
  ///
  /// Returns one [PicCtrlDataSet] per registered item, with [slot] in the
  /// range 1..9 for custom picture controls (null for the pre-installed
  /// types, which we do not need).
  Future<List<PicCtrlEntry>> pictureControls({int shootingMode = 0}) async {
    _ensureOpen();
    final data = await _request(
      PtpOps.getPicCtrlDataList,
      param1: 0xFFFFFFFF, // all PicCtrlItems
      param2: shootingMode,
      expectData: true,
    );
    final out = <PicCtrlEntry>[];
    var off = 0;
    final count = _u32(data, off);
    off += 4;
    for (var i = 0; i < count; i++) {
      off += 2; // DTS (redundant; sizes are inferred below)
      if (off + 2 > data.length) {
        throw const FormatException('truncated picture control list');
      }
      final picCtrlItem = _u16(data, off);
      off += 2;
      // Each element is: [Default DataSet][Current DataSet], each 36 or
      // 614 bytes depending on its own CustomCurveFlag byte (offset 35).
      final sizeA = data[off + 35] != 0 ? 614 : 36;
      if (off + sizeA > data.length) {
        throw const FormatException('truncated picture control list');
      }
      final defaultDs = data.sublist(off, off + sizeA);
      off += sizeA;
      final sizeB = data[off + 35] != 0 ? 614 : 36;
      if (off + sizeB > data.length) {
        throw const FormatException('truncated picture control list');
      }
      final currentDs = data.sublist(off, off + sizeB);
      off += sizeB;
      out.add(PicCtrlEntry(
        picCtrlItem: picCtrlItem,
        slot: PicCtrlItem.slotOf(picCtrlItem),
        data: PicCtrlDataSet.decode(currentDs),
        defaultData: PicCtrlDataSet.decode(defaultDs),
      ));
    }
    return out;
  }

  /// One registered picture control (current or default setting).
  Future<PicCtrlDataSet> pictureControl(
    int slot, {
    bool defaultValue = false,
    int shootingMode = 0,
  }) async {
    _ensureOpen();
    final data = await _request(
      PtpOps.getPicCtrlData,
      param1: PicCtrlItem.customSlot(slot),
      param2: defaultValue ? 1 : 0,
      param3: shootingMode,
      expectData: true,
    );
    return PicCtrlDataSet.decode(data);
  }

  /// Register [dataSet] as a new custom picture control in slot [slot]
  /// (1..9). When [existing] is true the slot's current control is
  /// overwritten in place (its base picture control must match).
  Future<void> registerPictureControl(
    int slot,
    PicCtrlDataSet dataSet, {
    bool existing = false,
    int shootingMode = 0,
  }) async {
    _ensureOpen();
    final response = await _sendCommandWithData(
      PtpCommand(
        operation: PtpOps.setPicCtrlData,
        transactionId: _nextTx(),
        param1: PicCtrlItem.customSlot(slot),
        param2: existing ? 1 : 0,
        param3: shootingMode,
      ),
      dataSet.encode(),
    );
    _check(response);
  }

  void dispose() {
    if (_open) {
      // Best-effort, fire-and-forget; the transport owns the hardware.
      close().catchError((_) {});
    }
    _transport.dispose();
  }

  // ------------------------------------------------------------ internals --

  int _nextTx() {
    if (_transactionId == 0xFFFFFFFE) _transactionId = 1;
    return _transactionId++;
  }

  void _ensureOpen() {
    if (!_open) {
      throw StateError('no camera session; call open() first');
    }
  }

  void _check(PtpResponse r) {
    if (!r.ok) {
      throw MtpOperationError(PtpRc.name(r.code), r.code);
    }
  }

  /// Send a command (no host data), optionally receive a data block, then
  /// the response. Returns the data payload (empty when none expected).
  Future<List<int>> _request(
    int operation, {
    int param1 = 0,
    int param2 = 0,
    int param3 = 0,
    bool expectData = false,
  }) async {
    final (response, data) = await _sendAndRespond(
      PtpCommand(
        operation: operation,
        transactionId: _nextTx(),
        param1: param1,
        param2: param2,
        param3: param3,
      ),
      expectData: expectData,
    );
    _check(response);
    return data;
  }

  Future<(PtpResponse, List<int>)> _sendAndRespond(
    PtpCommand command, {
    bool expectData = false,
  }) async {
    var data = <int>[];
    await _transport.write(command.toContainer().toBytes());
    if (expectData) {
      final c = await _transport.readContainer();
      if (c.type != PtpContainer.typeData) {
        throw const FormatException('expected a data block before the response');
      }
      data = c.payload;
    }
    final r = await _transport.readContainer();
    return (PtpResponse.parse(r), data);
  }

  /// Send a command, then a host→camera data block, then the response.
  Future<PtpResponse> _sendCommandWithData(
    PtpCommand command,
    List<int> data,
  ) async {
    await _transport.write(command.toContainer().toBytes());
    final dataContainer = PtpContainer(
      type: PtpContainer.typeData,
      code: command.operation,
      transactionId: command.transactionId,
      payload: Uint8List.fromList(data),
    );
    await _transport.write(dataContainer.toBytes());
    final r = await _transport.readContainer();
    return PtpResponse.parse(r);
  }

  int _u16(List<int> b, int off) => b[off] | (b[off + 1] << 8);
  int _u32(List<int> b, int off) =>
      b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24);
}

/// A picture control entry from [MtpSession.pictureControls].
class PicCtrlEntry {
  const PicCtrlEntry({
    required this.picCtrlItem,
    required this.slot,
    required this.data,
    this.defaultData,
  });

  /// Raw PicCtrlItem (1..120 pre-installed/creative, 201..209 custom).
  final int picCtrlItem;

  /// 1..9 for custom picture controls, null otherwise.
  final int? slot;

  /// The current setting.
  final PicCtrlDataSet data;

  /// The factory default for this control.
  final PicCtrlDataSet? defaultData;
}

/// The camera answered a command with a non-OK response code.
class MtpOperationError implements Exception {
  const MtpOperationError(this.name, this.code);

  final String name;
  final int code;

  @override
  String toString() => 'camera rejected the operation: $name';
}