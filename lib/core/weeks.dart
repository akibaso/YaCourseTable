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
    for (final course in schedule.courses) {
      for (final slot in course.timeSlots) {
        if (slot.dayOfWeek == dayOfWeek && weekInRange(week, slot.weekSpec)) {
          result.add(course);
          break;
        }
      }
    }
    return result;
  }
}
