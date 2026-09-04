import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/core/export_service.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/parsers/ics_parser.dart';

void main() {
  // 与 export_service_test 相同的课表数据：2 周，周一第 1-2 节 高等数学。
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

  test('ICS 导出 -> ICS 导入 互逆（round-trip）', () {
    final ics = ExportService.toIcs(data);
    final courses =
        IcsParser.parse(utf8.encode(ics), 'a', '2026-09-07');
    // 2 周 × 每周 1 个事件 = 2 门课程
    expect(courses.length, 2);
    expect(courses.first.name, '高等数学');
    expect(courses.first.teacher, '葛健');
    expect(courses.first.venue, '教三楼706');
    final slot = courses.first.timeSlots.first;
    expect(slot.dayOfWeek, 1);
    expect(slot.startPeriod, 1);
    expect(slot.endPeriod, 2);
    // 两周分别落在第 1、2 周
    expect(courses[0].timeSlots.first.weekSpec.contains(1), isTrue);
    expect(courses[1].timeSlots.first.weekSpec.contains(2), isTrue);
  });

  test('解析外部 ICS：事件日期换算周序号、时间映射节次', () {
    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:ext-1',
      'DTSTART:20260907T080000',
      'DTEND:20260907T085000',
      'SUMMARY:线性代数',
      // ICS 文件中 DESCRIPTION 的换行是转义的 \n（反斜杠+n 两个字符）。
      r'DESCRIPTION:教师:张三\n地点:逸夫楼A101',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
    final courses =
        IcsParser.parse(utf8.encode(ics), 'a', '2026-09-07');
    expect(courses.length, 1);
    expect(courses.first.name, '线性代数');
    expect(courses.first.teacher, '张三');
    expect(courses.first.venue, '逸夫楼A101');
    final slot = courses.first.timeSlots.first;
    expect(slot.dayOfWeek, 1); // 2026-09-07 是周一
    expect(slot.startPeriod, 1); // 08:00 命中第 1 节
    expect(slot.endPeriod, 1); // 08:50 仍在第 1 节内
    expect(slot.weekSpec.contains(1), isTrue);
  });

  test('开学日期之前的事件被跳过', () {
    final ics = [
      'BEGIN:VCALENDAR',
      'BEGIN:VEVENT',
      'UID:early',
      'DTSTART:20260901T080000',
      'SUMMARY:考前复习',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
    final courses =
        IcsParser.parse(utf8.encode(ics), 'a', '2026-09-07');
    expect(courses, isEmpty);
  });

  test('ICS 折行（行首空格续行）被正确展平', () {
    final ics = [
      'BEGIN:VCALENDAR',
      'BEGIN:VEVENT',
      'UID:folded',
      'DTSTART:20260907T080000',
      'SUMMARY:离散数学-导',
      // 折行：行首空格 + 续行内容是同一物理行。
      ' 论（每周三）',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\n');
    final courses =
        IcsParser.parse(utf8.encode(ics), 'a', '2026-09-07');
    expect(courses.length, 1);
    expect(courses.first.name, '离散数学-导论（每周三）');
  });
}
