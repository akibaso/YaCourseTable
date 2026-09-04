import 'package:html/parser.dart';

import '../core/models.dart';
import 'schedule_parser.dart';

/// Parses HTML schedule files (旧强智教务等导出的 HTML 课表).
class HtmlParser {
  static List<Course> parseHtml(String html, String scheduleId) {
    final doc = parse(html);
    final courses = <Course>[];
    for (final table in doc.querySelectorAll('table')) {
      final rows = table.querySelectorAll('tr');
      int? headerIdx;
      final dayCols = <int, int>{};
      for (var r = 0; r < rows.length; r++) {
        final cells = rows[r].querySelectorAll('td, th');
        var found = false;
        for (var c = 0; c < cells.length; c++) {
          final text = cells[c].text.trim();
          final day = ScheduleParser.dayNumber(text);
          if (day != null) {
            dayCols[day] = c;
            found = true;
          }
        }
        if (found) {
          headerIdx = r;
          break;
        }
      }
      if (headerIdx == null) continue;
      for (var r = headerIdx + 1; r < rows.length; r++) {
        final cells = rows[r].querySelectorAll('td, th');
        for (final entry in dayCols.entries) {
          final day = entry.key;
          final col = entry.value;
          if (col >= cells.length) continue;
          final cellText = cells[col].text.trim();
          if (cellText.isEmpty) continue;
          if (RegExp(r'^\d+$').hasMatch(cellText)) continue; // 节次数字行（时段标签）
          courses.addAll(ScheduleParser.parseCell(cellText, day, scheduleId));
        }
      }
    }
    return courses;
  }
}
