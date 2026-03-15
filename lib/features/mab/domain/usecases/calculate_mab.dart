import '../entities/mab_record.dart';
import '../entities/mab_status.dart';

class CalculateMab {
  MabStatus call({
    required List<MabRecord> monthRecords,
    required int month,
    required int year,
    double threshold = 10000,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final totalDaysInMonth = DateTime(year, month + 1, 0).day;

    final sumSoFar = monthRecords.fold(0.0, (sum, record) => sum + record.endOfDayBalance);
    final currentMab = sumSoFar / totalDaysInMonth;

    final ratio = currentMab / threshold;
    MabZone zone;
    if (ratio >= 1.0) {
      zone = MabZone.safe;
    } else if (ratio >= 0.85) {
      zone = MabZone.middle;
    } else if (ratio >= 0.70) {
      zone = MabZone.danger;
    } else {
      zone = MabZone.fine;
    }

    final requiredSum = threshold * totalDaysInMonth;
    final remainingDays = totalDaysInMonth - effectiveNow.day;

    final double minDailyNeeded;
    if (remainingDays > 0) {
      minDailyNeeded = (requiredSum - sumSoFar) / remainingDays;
    } else {
      minDailyNeeded = 0;
    }

    // Logic fix: if it's the last day or month passed, safety depends on currentMab >= threshold
    final bool isSafe;
    if (remainingDays > 0) {
      isSafe = minDailyNeeded <= 0;
    } else {
      isSafe = currentMab >= threshold;
    }

    String instruction;
    if (isSafe) {
      instruction = 'MAB secured for this month \u2705';
    } else if (remainingDays <= 0) {
      instruction = 'Last day \u2014 fine may be charged tomorrow';
    } else {
      instruction = 'Keep \u20B9${minDailyNeeded.round()} or above for $remainingDays more days';
    }

    return MabStatus(
      currentMab: currentMab,
      requiredMin: threshold,
      zone: zone,
      minDailyNeeded: minDailyNeeded,
      remainingDays: remainingDays,
      daysRecorded: monthRecords.length,
      isSafe: isSafe,
      instruction: instruction,
    );
  }
}
