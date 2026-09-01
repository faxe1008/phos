import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

/// Scripted in-memory transport: records everything the session writes and
/// replays queued containers in order.
class FakeTransport implements UsbTransport {
  final List<List<int>> written = [];
  final List<PtpContainer> scripted = [];
  int reads = 0;

  @override
  Future<void> write(List<int> bytes) async {
    written.add(bytes);
  }

  @override
  Future<PtpContainer> readContainer({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (reads >= scripted.length) {
      throw StateError('no more scripted containers (reads=$reads)');
    }
    return scripted[reads++];
  }

  @override
  Future<void> recover() async {}

  @override
  void dispose() {}
}

PtpContainer resp(int tx, {int code = 0x5000, int p1 = 0, int p2 = 0}) {
  // Response payload is exactly [Param1 u32 LE][Param2 u32 LE].
  final p = <int>[
    p1 & 0xff,
    (p1 >> 8) & 0xff,
    (p1 >> 16) & 0xff,
    (p1 >> 24) & 0xff,
    p2 & 0xff,
    (p2 >> 8) & 0xff,
    (p2 >> 16) & 0xff,
    (p2 >> 24) & 0xff,
  ];
  return PtpContainer(
    type: PtpContainer.typeResponse,
    code: code,
    transactionId: tx,
    payload: p,
  );
}

PtpContainer data(int tx, int code, List<int> payload) => PtpContainer(
      type: PtpContainer.typeData,
      code: code,
      transactionId: tx,
      payload: payload,
    );

void add16(List<int> b, int v) {
  b.add(v & 0xff);
  b.add((v >> 8) & 0xff);
}

PtpCommand cmd(PtpContainer c) => PtpCommand(
      operation: c.code,
      transactionId: c.transactionId,
      param1: c.payload.length >= 4
          ? c.payload[0] |
              (c.payload[1] << 8) |
              (c.payload[2] << 16) |
              (c.payload[3] << 24)
          : null,
      param2: c.payload.length >= 8
          ? c.payload[4] |
              (c.payload[5] << 8) |
              (c.payload[6] << 16) |
              (c.payload[7] << 24)
          : null,
      param3: c.payload.length >= 12
          ? c.payload[8] |
              (c.payload[9] << 8) |
              (c.payload[10] << 16) |
              (c.payload[11] << 24)
          : null,
    );

void main() {
  late FakeTransport t;

  setUp(() => t = FakeTransport());

  MtpSession openSessionWith(FakeTransport t) {
    // GetDeviceInfo (tx 1) -> data + ok; OpenSession (tx 0) -> ok p1=42.
    t.scripted
      ..add(data(1, PtpOps.getDeviceInfo, List.filled(36, 7)))
      ..add(resp(1))
      ..add(resp(0, p1: 42));
    return MtpSession(t);
  }

  group('session lifecycle', () {
    test('open performs GetDeviceInfo then OpenSession', () async {
      final s = openSessionWith(t);
      await s.open();
      expect(s.isOpen, isTrue);
      expect(s.sessionHandle, 42);
      expect(t.written.length, 2);

      final d = PtpContainer.parse(t.written[0]);
      expect(d.code, PtpOps.getDeviceInfo);
      expect(d.transactionId, 1);

      final o = PtpContainer.parse(t.written[1]);
      expect(o.code, PtpOps.openSession);
      expect(o.transactionId, 0); // spec: OpenSession is always tx 0
      expect(cmd(o).param1, 1); // non-zero SessionID
    });

    test('close sends CloseSession with the session handle', () async {
      final s = openSessionWith(t);
      await s.open();
      t.scripted.add(resp(1));
      await s.close();
      expect(s.isOpen, isFalse);

      final c = PtpContainer.parse(t.written.last);
      expect(c.code, PtpOps.closeSession);
      expect(c.transactionId, 1);
      expect(cmd(c).param1, 42);
    });

    test('commands before open() throw', () async {
      final s = MtpSession(t);
      expect(
        () => s.registerPictureControl(
          1,
          PicCtrlDataSet(basePictureControl: 1, registrationName: 'x'),
        ),
        throwsStateError,
      );
    });
  });

  group('SetPicCtrlData', () {
    test('sends command, host data, expects OK', () async {
      final s = openSessionWith(t);
      await s.open();

      final ds = PicCtrlDataSet(
        basePictureControl: 1,
        registrationName: 'Provia 100F',
        contrast: -12,
      );
      t.scripted.add(resp(1));
      await s.registerPictureControl(1, ds, existing: false);

      // command
      final c = PtpContainer.parse(t.written[2]);
      expect(c.type, PtpContainer.typeCommand);
      expect(c.code, PtpOps.setPicCtrlData);
      expect(c.transactionId, 1);
      final cp = cmd(c);
      expect(cp.param1, 201); // custom slot 1
      expect(cp.param2, 0); // new control
      expect(cp.param3, 0); // still photo

      // host data block
      final d = PtpContainer.parse(t.written[3]);
      expect(d.type, PtpContainer.typeData);
      expect(d.code, PtpOps.setPicCtrlData);
      expect(d.transactionId, 1);
      expect(PicCtrlDataSet.decode(d.payload).registrationName, 'Provia 100F');
    });

    test('existing flag sets ModifiedFlag', () async {
      final s = openSessionWith(t);
      await s.open();
      t.scripted.add(resp(1));
      await s.registerPictureControl(
        9,
        PicCtrlDataSet(basePictureControl: 1, registrationName: 'x'),
        existing: true,
        shootingMode: 1,
      );
      final c = cmd(PtpContainer.parse(t.written[2]));
      expect(c.param1, 209);
      expect(c.param2, 1);
      expect(c.param3, 1);
    });

    test('non-OK response throws MtpOperationError', () async {
      final s = openSessionWith(t);
      await s.open();
      t.scripted.add(resp(1, code: 0x500B));
      await expectLater(
        s.registerPictureControl(
          1,
          PicCtrlDataSet(basePictureControl: 1, registrationName: 'x'),
        ),
        throwsA(
          isA<MtpOperationError>()
              .having((e) => e.name, 'name', 'Invalid_Parameter'),
        ),
      );
    });
  });

  group('GetPicCtrlData', () {
    test('reads one control from a slot', () async {
      final s = openSessionWith(t);
      await s.open();

      final ds = PicCtrlDataSet(
        basePictureControl: 3,
        registrationName: 'Vivid back',
        saturation: 12,
      );
      t.scripted
        ..add(data(1, PtpOps.getPicCtrlData, ds.encode()))
        ..add(resp(1));

      final got = await s.pictureControl(3, defaultValue: true);
      expect(got.registrationName, 'Vivid back');
      expect(got.saturation, 12);

      final c = cmd(PtpContainer.parse(t.written[2]));
      expect(c.param1, 203);
      expect(c.param2, 1); // default value
      expect(c.param3, 0);
    });
  });

  group('GetPicCtrlDataList', () {
    test('parses a two-entry list with mixed curve sizes', () async {
      final s = openSessionWith(t);
      await s.open();

      final dsA = PicCtrlDataSet(
        basePictureControl: 1,
        registrationName: 'Slot One',
      );
      final dsB = PicCtrlDataSet(
        basePictureControl: 1,
        registrationName: 'Slot Two',
      );
      final dsBWithCurve = PicCtrlDataSet(
        basePictureControl: 1,
        registrationName: 'Slot Two',
        customCurveFlag: true,
        lut: PicCtrlDataSet.lutFromToneCurve(ToneCurve.identity()),
      );
      expect(dsA.encode().length, 36);
      expect(dsBWithCurve.encode().length, 614);

      // List payload: count=2, then [DTS][Item][default][current] per entry.
      final list = <int>[];
      list.addAll([2, 0, 0, 0]); // count u32 LE
      add16(list, 76); // DTS (skipped by the parser)
      add16(list, 201);
      list.addAll(dsA.encode());
      list.addAll(dsB.encode());
      add16(list, 654);
      add16(list, 202);
      list.addAll(dsB.encode()); // default: no curve
      list.addAll(dsBWithCurve.encode()); // current: curved

      t.scripted
        ..add(data(1, PtpOps.getPicCtrlDataList, list))
        ..add(resp(1));

      final entries = await s.pictureControls();
      expect(entries.length, 2);
      expect(entries[0].slot, 1);
      expect(entries[0].picCtrlItem, 201);
      // Element 1: default = dsA, current = dsB.
      expect(entries[0].defaultData!.registrationName, 'Slot One');
      expect(entries[0].data.registrationName, 'Slot Two');
      expect(entries[0].data.customCurveFlag, isFalse);
      expect(entries[1].slot, 2);
      expect(entries[1].data.registrationName, 'Slot Two');
      expect(entries[1].data.customCurveFlag, isTrue);
      expect(entries[1].defaultData!.customCurveFlag, isFalse);

      final c = cmd(PtpContainer.parse(t.written[2]));
      expect(c.param1, 0xFFFFFFFF); // all items
      expect(c.param2, 0); // still photo
    });
  });
}
