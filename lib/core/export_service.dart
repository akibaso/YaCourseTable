import 'dart:convert';

import 'models.dart';
import 'weeks.dart';
import '../parsers/shared_link_parser.dart';

/// 导出课表：备份 JSON / ICS 日历文件 / 分享口令。
class ExportService {
  /// 备份 JSON：完整 AppData（多课表 + 多时间表），可用于重新导入。
  static String backupJson(AppData data) => jsonEncode(data.toJson());

  /// 分享口令：base64(AppData JSON)，与导入侧 SharedLinkParser.parse 对称。
  static String shareCode(AppData data) => SharedLinkParser.encode(data);

  /// ICS 日历文件：把指定课表（默认活动课表）展开成整个学期的具体课程事件。
  static String toIcs(AppData data, {String? scheduleId}) {
    final schedule = scheduleId != null
        ? (data.schedules.isEmpty
            ? null
            : data.schedules.firstWhere((s) => s.id == scheduleId,
                orElse: () => data.schedules.first))
        : data.activeSchedule();
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//YaCourseTable//CN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
    ];
    if (schedule != null) {
      final start = DateTime.parse(schedule.semesterStartIso);
      final times = schedule.periodTimes;
      for (var w = 1; w <= schedule.totalWeeks; w++) {
        for (final (course, slot) in Weeks.slotsForWeek(schedule, w)) {
          final days = (w - 1) * 7 + (slot.dayOfWeek - 1);
          final date = start.add(Duration(days: days));
          lines.add('BEGIN:VEVENT');
          lines.add('UID:${course.id}-w$w-d${slot.dayOfWeek}@yacoursetable');
          lines.add('DTSTART:${_icsDate(date)}T${_icsTime(times[slot.startPeriod - 1].startMin)}');
          lines.add('DTEND:${_icsDate(date)}T${_icsTime(times[slot.endPeriod - 1].endMin)}');
          lines.add('SUMMARY:${_icsEscape(course.name)}');
          final desc = [
            if (course.teacher != null) '教师:${_icsEscape(course.teacher!)}',
            if (course.venue != null) '地点:${_icsEscape(course.venue!)}',
            if (slot.weekSpec.describe().isNotEmpty) _icsEscape(slot.weekSpec.describe()),
          ].where((s) => s.isNotEmpty).join('\n');
          if (desc.isNotEmpty) {
            lines.add('DESCRIPTION:${_icsEscape(desc)}');
          }
          lines.add('END:VEVENT');
        }
      }
    }
    lines.add('END:VCALENDAR');
    return lines.join('\r\n');
  }

  static String _icsDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}$m$day';
  }

  static String _icsTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h${m}00';
  }

  /// ICS 文本转义：反斜杠、逗号、分号与换行（分号不转义会导致 Google 日历截断 DESCRIPTION）。
  static String _icsEscape(String s) =>
      s.replaceAll('\\', '\\\\')
          .replaceAll(',', '\\,')
          .replaceAll(';', '\\;')
          .replaceAll('\n', '\\n');
}
