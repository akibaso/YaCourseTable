import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/core/models.dart';

void main() {
  test('AppData JSON round-trip preserves multi-schedule + multi-week-plan', () {
    final data = AppData(
      activeScheduleId: 's1',
      activeWeekPlanId: 'p1',
      settings: AppSettings(themeMode: 'dark', reminderLeadMinutes: 10, remindersEnabled: true),
      schedules: [
        Schedule(
          id: 's1',
          name: '主课表',
          semesterStartIso: '2026-09-07',
          totalWeeks: 20,
          courses: [
            Course(
              id: 'c1',
              scheduleId: 's1',
              name: '概率论与数理统计A*',
              teacher: '廖勇凯',
              venue: '北综楼404',
              credit: 3.5,
              timeSlots: [
                TimeSlot(
                    dayOfWeek: 5,
                    startPeriod: 7,
                    endPeriod: 8,
                    weekSpec: WeekSpec(weeks: [1, 5, 7, 15])),
              ],
            ),
          ],
          weekPlans: [
            WeekPlan(id: 'p1', name: '第1-4周', weekStart: 1, weekEnd: 4),
            WeekPlan(id: 'p2', name: '第5-20周', weekStart: 5, weekEnd: 20),
          ],
        ),
        Schedule(
          id: 's2',
          name: '实习安排',
          semesterStartIso: '2026-09-07',
          weekPlans: [WeekPlan(id: 'p3', name: '第16-17周', weekStart: 16, weekEnd: 17)],
        ),
      ],
    );

    final restored = AppData.fromJson(jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>);

    expect(restored.schedules.length, 2);
    expect(restored.activeScheduleId, 's1');
    expect(restored.activeWeekPlanId, 'p1');
    expect(restored.settings.reminderLeadMinutes, 10);
    final s1 = restored.schedules[0];
    expect(s1.name, '主课表');
    expect(s1.weekPlans.length, 2);
    expect(s1.courses.single.name, '概率论与数理统计A*');
    expect(s1.courses.single.timeSlots.single.weekSpec.weeks, [1, 5, 7, 15]);
    expect(s1.courses.single.credit, 3.5);
  });

  test('empty AppData round-trip', () {
    final restored = AppData.fromJson(jsonDecode(jsonEncode(AppData().toJson())) as Map<String, dynamic>);
    expect(restored.schedules, isEmpty);
    expect(restored.settings.themeMode, 'system');
  });
}
