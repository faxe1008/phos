import 'package:phos_core/phos_core.dart';
import 'package:test/test.dart';

void main() {
  test('smooth curves remain monotonic and preserve control points', () {
    final curve = CurveBuilder.fromControlPoints(const [
      Point(64, 24),
      Point(128, 190),
      Point(192, 210),
    ]);

    expect(curve.points, const [
      Point(64, 24),
      Point(128, 190),
      Point(192, 210),
      Point(255, 255),
      Point(0, 0),
    ]);
    for (var i = 1; i < curve.lut.length; i++) {
      expect(curve.lut[i], greaterThanOrEqualTo(curve.lut[i - 1]));
    }
  });
}
