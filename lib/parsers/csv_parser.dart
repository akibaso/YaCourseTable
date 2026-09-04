import 'package:csv/csv.dart';

import '../core/models.dart';
import 'schedule_parser.dart';

/// Parses CSV schedule files: same grid layout as the Excel/PDF formats.
///
/// Layout: a header with 时间段/节次/星期一..星期日, then rows whose day
/// columns hold stacked course text. Because course cells contain line
/// breaks, the RFC-4180 quote handling merges the following 时段 label
/// ("上午") into the 星期日 cell — so one physical data row becomes part of
/// the SAME record as the header, shifting all course cells right. The
/// parser therefore scans records after the header and attributes a course
/// cell to the day column whose header appears nearest to its left
/// (tracking the day seen so far in the row).
class CsvParser {
  static List<Course> parseText(String text, String scheduleId) {
    final records = const CsvToListConverter().convert(text.trim());
    if (records.isEmpty) return [];

    // Locate the header (any cell that is a day name) and the day columns.
    int? headerIdx;
    final dayCols = <int, int>{};
    for (var r = 0; r < records.length; r++) {
      final row = records[r].cast<String>();
      var found = false;
      for (var c = 0; c < row.length; c++) {
        final day = ScheduleParser.dayNumber(row[c].trim());
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
    if (headerIdx == null) return [];

    final courses = <Course>[];
    for (var r = headerIdx; r < records.length; r++) {
      final row = records[r].cast<String>();
      // Re-scan the header day names in THIS row first (wrapped headers),
      // then for each non-empty cell assign the nearest preceding day.
      var lastDay = 0;
      for (var c = 0; c < row.length; c++) {
        final cell = row[c].trim();
        final headerDay = ScheduleParser.dayNumber(cell);
        if (headerDay != null) {
          lastDay = headerDay;
          continue;
        }
        if (cell.isEmpty) continue;
        if (RegExp(r'^\d+$').hasMatch(cell)) continue; // 节次数字行（时段标签）
        // '1-2' style 节次 labels sit left of the course column.
        if (RegExp(r'^\d+-\d+$').hasMatch(cell)) continue;
        if (lastDay == 0) continue;
        courses.addAll(ScheduleParser.parseCell(cell, lastDay, scheduleId));
      }
    }
    return courses;
  }
}