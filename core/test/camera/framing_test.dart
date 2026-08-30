import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

void main() {
  group('command containers', () {
    test('GetDeviceInfo byte-exact (tx 1)', () {
      final c = PtpCommand(
        operation: PtpOps.getDeviceInfo,
        transactionId: 1,
      ).toContainer();
      final b = c.toBytes();
      expect(
        b,
        [
          0x18, 0x00, 0x00, 0x00, // len 24
          0x01, 0x00, // command
          0x01, 0x10, // 0x1001
          0x01, 0x00, 0x00, 0x00, // tx 1
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // params
        ],
      );
    });

    test('SetPicCtrlData packs PicCtrlItem + flags (tx 5, slot 1)', () {
      final c = PtpCommand(
        operation: PtpOps.setPicCtrlData,
        transactionId: 5,
        param1: 201,
        param2: 0,
        param3: 0,
      ).toContainer();
      final b = c.toBytes();
      expect(b[0] | (b[1] << 8), 24);
      expect(b[4] | (b[5] << 8), 1); // command
      expect(b[6] | (b[7] << 8), 0x90CD);
      expect(b[8] | (b[9] << 8), 5);
      // params little-endian
      expect(b.sublist(12, 16), [0xC9, 0x00, 0x00, 0x00]); // 201
      expect(b.sublist(16, 20), [0, 0, 0, 0]);
      expect(b.sublist(20, 24), [0, 0, 0, 0]);
    });
  });

  group('data containers', () {
    test('hosts data block for SetPicCtrlData', () {
      final c = PtpContainer(
        type: PtpContainer.typeData,
        code: PtpOps.setPicCtrlData,
        transactionId: 5,
        payload: [0x49, 0x30, 0x01, 0x02],
      );
      final b = c.toBytes();
      expect(b[0] | (b[1] << 8), 16); // 12 header + 4 payload
      expect(b[4] | (b[5] << 8), 2); // data
      expect(b[6] | (b[7] << 8), 0x90CD);
      expect(b.sublist(12), [0x49, 0x30, 0x01, 0x02]);
    });
  });

  group('parse', () {
    test('round-trips a response container', () {
      final b = <int>[
        0x14, 0x00, 0x00, 0x00, // len 20
        0x03, 0x00, // response
        0x00, 0x50, // 0x5000
        0x05, 0x00, 0x00, 0x00, // tx 5
        0, 0, 0, 0, 0, 0, 0, 0, // params
      ];
      final c = PtpContainer.parse(b);
      expect(c.type, PtpContainer.typeResponse);
      expect(c.code, 0x5000);
      expect(c.transactionId, 5);
      final r = PtpResponse.parse(c);
      expect(r.ok, isTrue);
      expect(r.param1, 0);
      expect(r.param2, 0);
    });

    test('parses payload with trailing bytes ignored', () {
      final b = <int>[
        0x14, 0x00, 0x00, 0x00,
        0x03, 0x00,
        0x00, 0x50,
        0x01, 0x00, 0x00, 0x00,
        1, 2, 3, 4, 5, 6, 7, 8,
        // trailing event bytes
        0x10, 0x00, 0x00, 0x00, 0x04, 0x00,
      ];
      final c = PtpContainer.parse(b);
      expect(c.code, 0x5000);
      expect(PtpResponse.parse(c).param1, 0x04030201);
    });

    test('rejects truncated input', () {
      expect(() => PtpContainer.parse([1, 2, 3]), throwsFormatException);
      // declared length beyond available bytes
      expect(
        () => PtpContainer.parse([0x64, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0]),
        throwsFormatException,
      );
    });
  });

  group('response codes', () {
    test('names known codes', () {
      expect(PtpRc.name(0x5000), 'OK');
      expect(PtpRc.name(0x500B), 'Invalid_Parameter');
      expect(PtpRc.name(0x5013), 'Session_Not_Open');
      expect(PtpRc.name(0x9999), startsWith('Unknown'));
    });
  });

  group('PicCtrlItem slots', () {
    test('custom slots map 1..9 to 201..209', () {
      expect(PicCtrlItem.customSlot(1), 201);
      expect(PicCtrlItem.customSlot(9), 209);
      expect(PicCtrlItem.slotOf(201), 1);
      expect(PicCtrlItem.slotOf(209), 9);
      expect(PicCtrlItem.slotOf(1), isNull);
      expect(() => PicCtrlItem.customSlot(10), throwsArgumentError);
      expect(() => PicCtrlItem.customSlot(0), throwsArgumentError);
    });
  });
}