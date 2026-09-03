import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/weeks.dart';

void main() {
  group('Weeks', () {
    test('before semester start => week 0', () {
      expect(Weeks.currentWeek(DateTime(2026, 9, 7), DateTime(2026, 9, 3)), 0);
    });

    test('week numbering is 1-based from start', () {
      expect(Weeks.currentWeek(DateTime(2026, 9, 7), DateTime(2026, 9, 7)), 1);
      expect(Weeks.currentWeek(DateTime(2026, 9, 7), DateTime(2026, 9, 15)), 2);
      expect(Weeks.currentWeek(DateTime(2026, 9, 7), DateTime(2026, 9, 22)), 3);
    });

    test('week range + odd/even via WeekSpec', () {
      final spec = WeekSpec(weeks: [2, 5, 7, 12], oddEven: 'all');
      expect(Weeks.weekInRange(3, spec), isTrue);
      expect(Weeks.weekInRange(6, spec), isFalse);
      expect(Weeks.weekInRange(9, spec), isTrue);
      expect(Weeks.weekInRange(13, spec), isFalse);

      final odd = WeekSpec(weeks: [1, 20], oddEven: 'odd');
      expect(Weeks.weekInRange(1, odd), isTrue);
      expect(Weeks.weekInRange(2, odd), isFalse);
      expect(Weeks.weekInRange(3, odd), isTrue);
    });

    test('week plan range + odd/even', () {
      final plan = WeekPlan(id: 'p1', name: '第1-4周', weekStart: 1, weekEnd: 4);
      expect(Weeks.weekInPlan(3, plan), isTrue);
      expect(Weeks.weekInPlan(5, plan), isFalse);

      final oddPlan = WeekPlan(
          id: 'p2', name: '第5-10周(单)', weekStart: 5, weekEnd: 10, oddEven: 'odd');
      expect(Weeks.weekInPlan(5, oddPlan), isTrue);
      expect(Weeks.weekInPlan(6, oddPlan), isFalse);
    });

    test('coursesForDay filters by day + week spec', () {
      final schedule = Schedule(
        id: 's1',
        name: '2026-2027-1',
        semesterStartIso: '2026-09-07',
        courses: [
          Course(
            id: 'c1',
            scheduleId: 's1',
            name: '模拟电子技术*',
            teacher: '葛健',
            venue: '教三楼706',
            timeSlots: [
              TimeSlot(
                dayOfWeek: 1,
                startPeriod: 1,
                endPeriod: 2,
                weekSpec: WeekSpec(weeks: [1, 5, 7, 12]),
              )
            ],
          ),
          Course(
            id: 'c2',
            scheduleId: 's1',
            name: '数字电子技术*',
            teacher: '熊永华',
            venue: '东教楼C0310',
            timeSlots: [
              TimeSlot(
                dayOfWeek: 1,
                startPeriod: 3,
                endPeriod: 4,
                weekSpec: WeekSpec(weeks: [9, 16]),
              )
            ],
          ),
        ],
      );
      expect(Weeks.coursesForDay(schedule, 3, 1).map((c) => c.name).toList(),
          ['模拟电子技术*']);
      // Week 10 falls in c1's 7-12 range AND c2's 9-16 range => both.
      expect(Weeks.coursesForDay(schedule, 10, 1).map((c) => c.name).toList(),
          ['模拟电子技术*', '数字电子技术*']);
      expect(Weeks.coursesForDay(schedule, 10, 2), isEmpty);
    });
  });
}
