/// Static weekly effective-set reference values for one trainable muscle
/// (Intermediate landmark set — see specs/003-muscle-volume-report/spec.md).
///
/// These are code-owned product constants, not stored in SQLite: they are
/// not user-editable in this feature and keeping them in code avoids a
/// migration for every future tuning pass.
class VolumeLandmark {
  /// Maintenance volume — minimum weekly sets to avoid losing adaptations.
  final double mv;

  /// Minimum effective volume — below this is Undertrained.
  final double mev;

  /// Lower bound of the target adaptive band (progressive-disclosure only).
  final double mavLow;

  /// Upper bound of the target adaptive band (progressive-disclosure only).
  final double mavHigh;

  /// Max recoverable volume — above this is Overtrained.
  final double mrv;

  const VolumeLandmark({
    required this.mv,
    required this.mev,
    required this.mavLow,
    required this.mavHigh,
    required this.mrv,
  });
}
