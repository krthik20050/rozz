
enum MabZone { safe, middle, danger, fine }

class MabStatus {
  final double currentMab;
  final double requiredMin;
  final MabZone zone;
  final double minDailyNeeded;
  final int remainingDays;
  final int daysRecorded;
  final bool isSafe;
  final String instruction;

  MabStatus({
    required this.currentMab,
    required this.requiredMin,
    required this.zone,
    required this.minDailyNeeded,
    required this.remainingDays,
    required this.daysRecorded,
    required this.isSafe,
    required this.instruction,
  });
}
