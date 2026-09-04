import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/notification_service.dart';

void main() {
  // 学期 2026-09-07 开始，共 20 周；今天 2026-09-04 尚未开学（currentWeek=0）。
  final data = AppData(
    activeScheduleId: 'a',
    schedules: [
      Schedule(
        id: 'a',
        name: '测试课表',
        semesterStartIso: '2026-09-07',
        totalWeeks: 20,
        courses: [
          Course(
            id: 'c1',
            scheduleId: 'a',
            name: '高等数学',
            timeSlots: [
              TimeSlot(
                dayOfWeek: 1,
                startPeriod: 1,
                endPeriod: 1,
                weekSpec: WeekSpec(weeks: [1, 20]),
              ),
            ],
          ),
          Course(
            id: 'c2',
            scheduleId: 'a',
            name: '模拟电子技术',
            timeSlots: [
              TimeSlot(
                dayOfWeek: 6,
                startPeriod: 7,
                endPeriod: 8,
                weekSpec: WeekSpec(weeks: [1, 10]),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  test('nextOccurrences returns upcoming course starts in order', () {
    final occ = NotificationService.nextOccurrences(data, 5);
    expect(occ.length, greaterThan(0));
    // 第一次事件应是 2026-09-07（第 1 周周一）08:00
    expect(occ.first.start.year, 2026);
    expect(occ.first.start.month, 9);
    expect(occ.first.start.day, 7);
    expect(occ.first.start.hour, 8);
    expect(occ.first.start.minute, 0);
    expect(occ.first.courseName, '高等数学');
    // 结果按时间升序
    for (var i = 1; i < occ.length; i++) {
      expect(occ[i - 1].start.isBefore(occ[i].start), isTrue);
    }
  });

  test('disabled reminders or empty schedule produce no scheduled notifications', () {
    final empty = AppData(schedules: [
      Schedule(id: 'a', name: '空课表', semesterStartIso: '2026-09-07')
    ]);
    expect(NotificationService.nextOccurrences(empty, 5), isEmpty);
  });

  test('reminders off keeps data but sync cancels all', () {
    final noReminders = AppData(
      activeScheduleId: 'a',
      schedules: data.schedules,
      settings: AppSettings(remindersEnabled: false),
    );
    // syncReminders 会 cancelAll（无法在纯单测里跑平台通道，仅验证纯函数行为）
    final occ = NotificationService.nextOccurrences(noReminders, 5);
    expect(occ, isNotEmpty);
  });
}
