import 'dart:math' as math;

import 'models.dart';

class Weeks {
  /// 0 means the semester has not started yet.
  static int currentWeek(DateTime semesterStart, DateTime today) {
    if (today.isBefore(semesterStart)) return 0;
    final days = today.difference(semesterStart).inDays;
    return math.max(days ~/ 7 + 1, 1);
  }

  static bool weekInRange(int week, WeekSpec spec) => spec.contains(week);

  /// Whether [week] falls inside a [WeekPlan] (contiguous range + odd/even).
  static bool weekInPlan(int week, WeekPlan plan) {
    if (week < plan.weekStart || week > plan.weekEnd) return false;
    if (plan.oddEven == 'odd' && week.isEven) return false;
    if (plan.oddEven == 'even' && week.isOdd) return false;
    return true;
  }

  /// Courses that run on [dayOfWeek] during [week] within [schedule].
  static List<Course> coursesForDay(Schedule schedule, int week, int dayOfWeek) {
    final result = <Course>[];
    for (final (course, slot) in slotsForWeek(schedule, week)) {
      if (slot.dayOfWeek == dayOfWeek) {
        if (!result.any((c) => c.id == course.id)) result.add(course);
      }
    }
    return result;
  }

  /// All (course, slot) pairs that run during [week], validated against
  /// the schedule's period times. Shared by ICS 导出 / 课程提醒 / 日视图，
  /// 避免各处重复实现同一套展开逻辑。
  static List<(Course, TimeSlot)> slotsForWeek(Schedule schedule, int week) {
    final times = schedule.periodTimes;
    final result = <(Course, TimeSlot)>[];
    for (final course in schedule.courses) {
      for (final slot in course.timeSlots) {
        if (slot.dayOfWeek < 1 || slot.dayOfWeek > 7) continue;
        if (!slot.weekSpec.contains(week)) continue;
        if (slot.startPeriod < 1 || slot.startPeriod > times.length) continue;
        if (slot.endPeriod < slot.startPeriod || slot.endPeriod > times.length) continue;
        result.add((course, slot));
      }
    }
    return result;
  }
}
