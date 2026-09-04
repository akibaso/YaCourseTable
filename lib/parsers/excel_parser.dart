import 'package:excel/excel.dart';

import '../core/models.dart';
import 'schedule_parser.dart';

/// Parses .xls / .xlsx schedule files (Excel 模板 / 教务导出).
///
/// Expected layout: header row with 时间段/节次/星期一..星期日, then
/// period rows; day-of-week columns contain stacked course text.
class ExcelParser {
  static List<Course> parseBytes(List<int> bytes, String scheduleId) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      return [];
    }
    final sheets = excel.sheets;
    if (sheets.isEmpty) return [];
    final sheetName = sheets.keys.first;
    final sheet = sheets[sheetName];
    if (sheet == null) return [];
    final rows = sheet.rows; // List<List<Data?>>
    if (rows.isEmpty) return [];

    // Locate header row and day-of-week column indices.
    int? headerIdx;
    final dayCols = <int, int>{}; // day -> column index
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      var found = false;
      for (var c = 0; c < row.length; c++) {
        final text = _cellText(row[c]);
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
    if (headerIdx == null) return [];

    final courses = <Course>[];
    for (var r = headerIdx + 1; r < rows.length; r++) {
      final row = rows[r];
      for (final entry in dayCols.entries) {
        final day = entry.key;
        final col = entry.value;
        if (col >= row.length) continue;
        final cellText = _cellText(row[col]).trim();
        if (cellText.isEmpty) continue;
        if (RegExp(r'^\d+$').hasMatch(cellText)) continue; // 节次数字行（时段标签）
        courses.addAll(ScheduleParser.parseCell(cellText, day, scheduleId));
      }
    }
    return courses;
  }

  static String _cellText(Data? cell) => cell?.value?.toString() ?? '';

}
