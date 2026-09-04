import 'volume_landmark.dart';

/// Athlete-facing weekly muscle-volume status. Exactly three states —
/// see specs/003-muscle-volume-report/design.md §3. Labels shown in the UI
/// must be exactly "Undertrained" / "Optimal" / "Overtrained".
enum MuscleVolumeStatus { undertrained, optimal, overtrained }

/// Computed weekly report row for one of the 21 taxonomy muscles.
class WeeklyMuscleVolume {
  final String muscle;
  final String region;
  final double effectiveSets;
  final int contributingSets;
  final VolumeLandmark landmark;
  final MuscleVolumeStatus status;

  /// True when [effectiveSets] < [landmark.mv]. Context-only; the visible
  /// status remains [MuscleVolumeStatus.undertrained] (FR-013).
  final bool belowMaintenance;

  const WeeklyMuscleVolume({
    required this.muscle,
    required this.region,
    required this.effectiveSets,
    required this.contributingSets,
    required this.landmark,
    required this.status,
    required this.belowMaintenance,
  });

  /// Builds a report row from raw effective-set totals, applying the
  /// FR-012/FR-013 status-classification rules:
  ///   effectiveSets <  mev          -> undertrained
  ///   mev <= effectiveSets <= mrv   -> optimal
  ///   effectiveSets >  mrv          -> overtrained
  factory WeeklyMuscleVolume.from({
    required String muscle,
    required String region,
    required double effectiveSets,
    required int contributingSets,
    required VolumeLandmark landmark,
  }) {
    final MuscleVolumeStatus status;
    if (effectiveSets < landmark.mev) {
      status = MuscleVolumeStatus.undertrained;
    } else if (effectiveSets <= landmark.mrv) {
      status = MuscleVolumeStatus.optimal;
    } else {
      status = MuscleVolumeStatus.overtrained;
    }
    return WeeklyMuscleVolume(
      muscle: muscle,
      region: region,
      effectiveSets: effectiveSets,
      contributingSets: contributingSets,
      landmark: landmark,
      status: status,
      belowMaintenance: effectiveSets < landmark.mv,
    );
  }
}
