/// A single data point for the strength progress chart.
class WeightHistoryPoint {
  final DateTime date;
  final double maxWeightKg;

  const WeightHistoryPoint({required this.date, required this.maxWeightKg});
}
