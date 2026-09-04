import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/core/export_service.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/parsers/shared_link_parser.dart';

void main() {
  final data = AppData(
    activeScheduleId: 'a',
    schedules: [
      Schedule(
        id: 'a',
        name: '测试课表',
        semesterStartIso: '2026-09-07',
        totalWeeks: 2,
        courses: [
          Course(
            id: 'c1',
            scheduleId: 'a',
            name: '高等数学',
            teacher: '葛健',
            venue: '教三楼706',
            timeSlots: [
              TimeSlot(
                dayOfWeek: 1,
                startPeriod: 1,
                endPeriod: 2,
                weekSpec: WeekSpec(weeks: [1, 2]),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  test('backupJson round-trips through AppData.fromJson', () {
    final json = ExportService.backupJson(data);
    final back = AppData.fromJson(jsonDecode(json) as Map<String, dynamic>);
    expect(back.schedules.length, data.schedules.length);
    expect(back.schedules.first.courses.first.name, '高等数学');
  });

  test('shareCode is parseable by SharedLinkParser', () {
    final code = ExportService.shareCode(data);
    final back = SharedLinkParser.parse(code);
    expect(back, isNotNull);
    expect(back!.schedules.length, 1);
  });

  test('toIcs expands weeks into VEVENT with clock times', () {
    final ics = ExportService.toIcs(data);
    expect(ics, startsWith('BEGIN:VCALENDAR'));
    expect(ics, endsWith('END:VCALENDAR'));
    // 第 1 周周一第 1-2 节：08:00-09:50
    expect(ics, contains('DTSTART:20260907T080000'));
    expect(ics, contains('DTEND:20260907T095000'));
    expect(ics, contains('SUMMARY:高等数学'));
    expect(ics, contains('UID:c1-w1-d1@yacoursetable'));
    // 第 2 周一：2026-09-14
    expect(ics, contains('DTSTART:20260914T080000'));
    // 共 2 个 VEVENT（两周各一次）
    expect(ics.split('BEGIN:VEVENT').length - 1, 2);
  });

  test('empty AppData exports empty calendar', () {
    final ics = ExportService.toIcs(AppData());
    expect(ics, startsWith('BEGIN:VCALENDAR'));
    expect(ics, isNot(contains('VEVENT')));
  });
}
