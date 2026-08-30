/// Capability matrix for a target camera.
///
/// The editor and the mappers consult this so unsupported fields can be
/// hidden or warned about, and so the same core can target other Z bodies
/// (or future ecosystems) without redesign.
class TargetProfile {
  const TargetProfile({
    required this.name,
    required this.cameraFamily,
    this.supportsToneCurve = true,
    this.supportsColorBlender = true,
    this.supportsColorGrading = true,
    this.maxNameLength = 19,
    this.toneMin = -100,
    this.toneMax = 100,
    this.sharpeningMin = -3,
    this.sharpeningMax = 9,
    this.detailMin = -5,
    this.detailMax = 5,
  });

  final String name;
  final String cameraFamily;

  final bool supportsToneCurve;
  final bool supportsColorBlender;
  final bool supportsColorGrading;
  final int maxNameLength;
  final double sharpeningMin;
  final double sharpeningMax;
  final double detailMin;
  final double detailMax;
  final int toneMin;
  final int toneMax;

  /// The Z50II reference target: full flexible-color Picture Control.
  static const z50ii = TargetProfile(
    name: 'Nikon Z50II',
    cameraFamily: 'nikon-z',
  );
}