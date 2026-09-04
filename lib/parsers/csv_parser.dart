import 'package:csv/csv.dart';

import '../core/models.dart';
import 'schedule_parser.dart';

/// Parses CSV schedule files: same grid layout as the Excel/PDF formats.
///
/// Layout: a header with 时间段/节次/星期一..星期日, then rows whose day
/// columns hold stacked course text. Because courses contain line breaks,
/// the RFC-4180 quote handling can merge several physical lines into one
/// record (the 节次 labels like "1-2" then appear mid-record). Both forms
/// are handled here.
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
      // Map each non-empty day cell to the nearest PRECEDING day column
      // (cells may be shifted right when earlier lines merged).
      var lastDay = 0;
      for (var c = 0; c < row.length; c++) {
        final cell = row[c].trim();
        final day = ScheduleParser.dayNumber(cell);
        if (day != null) {
          lastDay = day;
          continue;
        }
        if (cell.isEmpty) continue;
        if (RegExp(r'^\d+$').hasMatch(cell)) continue; // 节次数字行（时段标签）
        if (lastDay == 0) continue;
        courses.addAll(ScheduleParser.parseCell(cell, lastDay, scheduleId));
      }
    }
    return courses;
  }
}