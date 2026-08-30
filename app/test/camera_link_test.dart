import 'package:flutter_test/flutter_test.dart';
import 'package:phos_core/phos_core.dart';
import 'package:phos/camera/camera_link.dart';

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
      throw StateError('no more scripted containers');
    }
    return scripted[reads++];
  }

  @override
  Future<void> recover() async {}

  @override
  void dispose() {}
}

PtpContainer resp(int tx, {int code = 0x5000, int p1 = 0}) => PtpContainer(
      type: PtpContainer.typeResponse,
      code: code,
      transactionId: tx,
      payload: [
        p1 & 0xff, (p1 >> 8) & 0xff, (p1 >> 16) & 0xff, (p1 >> 24) & 0xff,
        0, 0, 0, 0,
      ],
    );

PtpContainer data(int tx, int code, List<int> payload) => PtpContainer(
      type: PtpContainer.typeData,
      code: code,
      transactionId: tx,
      payload: payload,
    );

void main() {
  test('send opens a session and registers the picture control', () async {
    final t = FakeTransport();
    // open(): GetDeviceInfo tx1 -> data + ok, OpenSession tx0 -> ok p1=7
    t.scripted
      ..add(data(1, PtpOps.getDeviceInfo, List.filled(36, 1)))
      ..add(resp(1))
      ..add(resp(0, p1: 7))
      // send(): SetPicCtrlData tx1 -> ok
      ..add(resp(1))
      // close(): CloseSession tx2 -> ok
      ..add(resp(2));

    final link = CameraLink(transport: t);
    await link.connect(name: '0', label: 'Fake Z50II');
    expect(link.isConnected, isTrue);
    expect(link.connectedLabel, 'Fake Z50II');

    final recipe = RecipeConverter.fromFujiText(
      'Name: Provia\n'
      'Base ISO: 160\n'
      'Dynamic Range: Auto\n'
      'Grain: 0\n'
      'Color: 0\n'
      'Col. Chr. Effect: 0\n'
      'Col. Chr. Blue: 0\n'
      'Highlight: 0\n'
      'Shadow: 0\n',
      name: 'Provia 100F',
    );

    await link.send(recipe, 4);

    // OpenSession used a fixed tx 0; the first real command is tx 1.
    final cmd = PtpContainer.parse(t.written[2]);
    expect(cmd.type, PtpContainer.typeCommand);
    expect(cmd.code, PtpOps.setPicCtrlData);
    expect(cmd.transactionId, 1);
    final p1 = cmd.payload[0] | (cmd.payload[1] << 8);
    final p2 = cmd.payload[4] | (cmd.payload[5] << 8);
    expect(p1, 204); // custom slot 4
    expect(p2, 0); // new control

    final dsPayload = PtpContainer.parse(t.written[3]);
    expect(dsPayload.type, PtpContainer.typeData);
    final ds = PicCtrlDataSet.decode(dsPayload.payload);
    expect(ds.registrationName, 'Provia 100F');

    await link.close();
    expect(link.isConnected, isFalse);
  });

  test('send on a closed link throws a state error', () async {
    final link = CameraLink(transport: FakeTransport());
    final recipe = RecipeConverter.fromFujiText(
      'Name: X\nBase ISO: 160\nDynamic Range: Auto\nGrain: 0\nColor: 0\n'
      'Col. Chr. Effect: 0\nCol. Chr. Blue: 0\nHighlight: 0\nShadow: 0\n',
      name: 'X',
    );
    expect(
      () => link.send(recipe, 1),
      throwsA(isA<StateError>().having((e) => e.toString(), 'msg',
          contains('no camera connected'))),
    );
  });
}