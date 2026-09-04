import 'dart:convert';
import 'dart:math' as math;

import '../core/models.dart';

/// 解析 .ics 日历文件（Google 日历 / 我们自己的 ICS 导出可互逆导入）。
///
/// 每个 VEVENT 变成一节课程：SUMMARY 是课程名，DTSTART/DTEND 按节次时间
/// （[PeriodTime]）映射为节次号，DESCRIPTION 里的 教师/地点 写入课程信息。
class IcsParser {
  /// 解析 ICS 字节流为课程列表。
  ///
  /// [semesterStartIso] 是课表开学日期：把事件的真实日期换算成周序号
  /// （周一为一周起点）。[periodTimes] 为空时用 [PeriodTime.defaultTimes]。
  static List<Course> parse(
    List<int> bytes,
    String scheduleId,
    String semesterStartIso, {
    List<PeriodTime>? periodTimes,
  }) {
    final times = periodTimes ?? PeriodTime.defaultTimes();
    final semesterStart = DateTime.parse(semesterStartIso);

    // 展平 ICS 折行（行首空格的续行）。
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = <String>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (lines.isNotEmpty) {
          lines[lines.length - 1] = lines[lines.length - 1] + line.substring(1);
        }
        continue;
      }
      lines.add(line);
    }

    final courses = <Course>[];
    String? summary;
    String? dtStart;
    String? dtEnd;
    String? description;
    String? uid;
    var inEvent = false;

    void flush(int index) {
      if (!inEvent || summary == null || dtStart == null) {
        summary = null;
        dtStart = null;
        dtEnd = null;
        description = null;
        uid = null;
        return;
      }
      final start = _parseIcsDateTime(dtStart!);
      final end = dtEnd == null ? null : _parseIcsDateTime(dtEnd!);
      if (start == null) {
        summary = null;
        dtStart = null;
        dtEnd = null;
        description = null;
        uid = null;
        return;
      }
      final days = start.date.difference(semesterStart).inDays;
      if (days < 0) {
        summary = null;
        dtStart = null;
        dtEnd = null;
        description = null;
        uid = null;
        return;
      }
      final week = days ~/ 7 + 1;
      final startMin = start.startMin;
      final endMin = end?.startMin ?? startMin + 50;
      final startPeriod = _periodIndexFor(times, startMin) + 1;
      final endPeriod = _periodIndexFor(times, endMin) + 1;

      String? teacher;
      String? venue;
      if (description != null) {
        for (final line in _unesc(description!).split('\n')) {
          final m = RegExp(r'^(?:教师|Teacher)[:：]\s*(.*)$').firstMatch(line);
          if (m != null && m.group(1) != null && m.group(1)!.isNotEmpty) {
            teacher = m.group(1)!.trim();
            continue;
          }
          final mv = RegExp(r'^(?:地点|Location)[:：]\s*(.*)$').firstMatch(line);
          if (mv != null && mv.group(1) != null && mv.group(1)!.isNotEmpty) {
            venue = mv.group(1)!.trim();
          }
        }
      }

      courses.add(
        Course(
          id: uid ?? 'ics_$index',
          scheduleId: scheduleId,
          name: _unesc(summary!),
          teacher: teacher,
          venue: venue,
          timeSlots: [
            TimeSlot(
              dayOfWeek: start.date.weekday, // Dart: 1=周一..7=周日
              startPeriod: startPeriod,
              endPeriod: math.max(endPeriod, startPeriod),
              weekSpec: WeekSpec(weeks: [week, week]),
            )
          ],
        ),
      );
      summary = null;
      dtStart = null;
      dtEnd = null;
      description = null;
      uid = null;
    }

    for (final line in lines) {
      if (line.startsWith('BEGIN:VEVENT')) {
        inEvent = true;
        continue;
      }
      if (line.startsWith('END:VEVENT')) {
        if (inEvent) flush(courses.length);
        inEvent = false;
        continue;
      }
      if (!inEvent) continue;
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = line.substring(0, colon);
      final value = line.substring(colon + 1);
      switch (key) {
        case 'SUMMARY':
          summary = value;
          break;
        case 'DTSTART':
          dtStart = value;
          break;
        case 'DTEND':
          dtEnd = value;
          break;
        case 'DESCRIPTION':
          description = value;
          break;
        case 'UID':
          uid = value;
          break;
      }
    }
    if (inEvent) flush(courses.length);
    return courses;
  }

  static int _periodIndexFor(List<PeriodTime> times, int minutes) {
    // 精确匹配节次开始时间；否则取包含该时间的节次（含节次结束点）；再否则取最接近的节次。
    for (var i = 0; i < times.length; i++) {
      if (times[i].startMin == minutes) return i;
    }
    for (var i = 0; i < times.length; i++) {
      if (minutes >= times[i].startMin && minutes <= times[i].endMin) return i;
    }
    var best = 0;
    var bestDist = 1 << 30;
    for (var i = 0; i < times.length; i++) {
      final dist = (times[i].startMin - minutes).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  /// ICS 转义还原：\n 换行、\; 分号、\, 逗号、\\ 反斜杠。
  static String _unesc(String s) {
    return s
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\\', '\\');
  }

  static _IcsTime? _parseIcsDateTime(String v) {
    // 支持 20260907T080000（本地时间，我们的导出格式）与纯日期 20260907。
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?)?$').firstMatch(v);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final date = DateTime(y, mo, d);
    final h = m.group(4);
    if (h == null) return _IcsTime(date, 0);
    final min = int.parse(h) * 60 + int.parse(m.group(5)!);
    return _IcsTime(date, min);
  }
}

class _IcsTime {
  final DateTime date;
  final int startMin;

  _IcsTime(this.date, this.startMin);
}
