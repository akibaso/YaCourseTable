import '../core/models.dart';
import 'pdf_text.dart';
import 'schedule_parser.dart';

/// Parses school schedule PDFs (教务系统导出格式):
/// 表头为 时间段/节次/星期一…星期日，单元格内可堆叠多门课程，
/// 每门课带 (节次范围) + 周次范围 + 校区/场地/教师/教学班/学分。
class PdfParser {
  /// Parse a PDF byte array into a list of courses.
  static List<Course> parse(List<int> bytes, String scheduleId) {
    final chunks = PdfText.extract(bytes);
    if (chunks.isEmpty) return [];

    // Timetable PDFs often span two pages that reuse the same day-column x
    // positions (page 2 = afternoon/evening periods). Process each page
    // independently so their columns never merge.
    final pages = <int>{...chunks.map((c) => c.page)};
    final courses = <Course>[];
    for (final p in pages) {
      courses.addAll(_parsePage(chunks.where((c) => c.page == p).toList(), scheduleId));
    }
    return courses;
  }

  static List<Course> _parsePage(List<TextChunk> chunks, String scheduleId) {

    // 1) cluster into rows by y (tolerance 8pt).
    final rows = clusterRows(chunks);

    // 2) locate the header row: the row containing any 星期X / 周X day name.
    int? headerRowIdx;
    final dayX = <int, List<TextChunk>>{};
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      var hasDay = false;
      for (final c in row) {
        final day = ScheduleParser.dayNumber(c.text.trim());
        if (day != null) {
          (dayX[day] ??= <TextChunk>[]).add(c);
          hasDay = true;
        }
      }
      if (hasDay) {
        headerRowIdx = r;
        break;
      }
    }
    if (headerRowIdx == null) return [];

    // 3) The grid is ordered 星期一..星期日, so the leftmost course column
    // is Monday. Cluster the course-content chunks (rows below the header)
    // by x-position to recover the day columns. Content = rows above the
    // header in visual terms = rows with smaller y (the rows array is sorted
    // by y ascending, so "before headerRowIdx" = BELOW the header row =
    // the grid area).
    final contentChunks = <TextChunk>[];
    for (var r = 0; r < headerRowIdx; r++) {
      contentChunks.addAll(rows[r]);
    }
    if (contentChunks.isEmpty) return [];

    // Period markers come from the 节次 column (the only pure-number chunks,
    // x < firstDayX). They delimit the per-period cell bands in y.
    final firstDayX = _minXOfDayOne(rows, headerRowIdx);
    final periodMarkers = <(double, int)>[]; // (y, periodNumber)
    for (var r = 0; r < headerRowIdx; r++) {
      for (final c in rows[r]) {
        if (c.x < firstDayX) {
          final t = TextChunk.decodeBytes(c.bytes).trim();
          final n = int.tryParse(t);
          if (n != null && n >= 1 && n <= 16) {
            periodMarkers.add((c.y, n));
          }
        }
      }
    }
    periodMarkers.sort((a, b) => b.$1.compareTo(a.$1)); // top of page first

    final clusters = <List<TextChunk>>[];
    final clusterX = <double>[];
    for (final c in contentChunks) {
      var placed = false;
      for (var i = 0; i < clusters.length; i++) {
        if ((c.x - clusterX[i]).abs() < 25) {
          clusters[i].add(c);
          clusterX[i] = (clusterX[i] * (clusters[i].length - 1) + c.x) / clusters[i].length;
          placed = true;
          break;
        }
      }
      if (!placed) {
        clusters.add([c]);
        clusterX.add(c.x);
      }
    }

    // Order clusters by x to map to weekdays (index 0 = Monday = day 1).
    final order = List<int>.generate(clusters.length, (i) => i)
      ..sort((a, b) => clusterX[a].compareTo(clusterX[b]));

    // Keep only the 7 day columns. The period column (节次) and the
    // 上午/下午/footer labels sit well LEFT of the first day column, but the
    // first COURSE column itself is ~29pt left of the 星期一 header — so the
    // exclusion must be generous (period column is at 节次 x≈78, far below).
    final dayIdx = <int>[];
    for (final ci in order) {
      if (clusterX[ci] < firstDayX - 40) continue; // period/label column
      if (dayIdx.length >= 7) break;
      dayIdx.add(ci);
    }

    final periodRe = RegExp(r'^\(\d+-\d+节\)');
    final starRe = RegExp(r'\*');
    final courses = <Course>[];
    for (var i = 0; i < dayIdx.length; i++) {
      final ci = dayIdx[i];
      final chunks = clusters[ci];

      // Split the column into stacked course cells. Within a cell the rendered
      // lines sit ~12pt apart; consecutive cells have a distinctly larger
      // gap. A fixed 20pt threshold works except when two courses in one
      // cell region are interleaved at a small offset — recover those by
      // splitting at NAME boundaries inside the band.
      final parts = <String>[];
      var anyCourse = false;
      final sorted = List<TextChunk>.from(chunks)
        ..sort((a, b) {
          final cmp = b.y.compareTo(a.y);
          if (cmp != 0) return cmp;
          return a.x.compareTo(b.x);
        });

      // Detect NAME lines: a line whose text ends with '*' or whose NEXT
      // line starts with '(x-y节)'. A name line starts a new course cell.
      final isName = <bool>[];
      for (var k = 0; k < sorted.length; k++) {
        final t = TextChunk.decodeBytes(sorted[k].bytes);
        final nxt = k + 1 < sorted.length ? TextChunk.decodeBytes(sorted[k + 1].bytes) : '';
        isName.add(starRe.hasMatch(t) || periodRe.hasMatch(nxt.trim()));
      }

      // Group into cells by gap AND name boundaries.
      final cells = <List<TextChunk>>[];
      var current = <TextChunk>[];
      var lastY = 0.0;
      for (var k = 0; k < sorted.length; k++) {
        final c = sorted[k];
        final startNew = current.isNotEmpty &&
            ((lastY - c.y) > 20 || isName[k] && !isName[k - 1]);
        if (startNew) {
          cells.add(current);
          current = [];
        }
        current.add(c);
        lastY = c.y;
      }
      if (current.isNotEmpty) cells.add(current);

      for (final cell in cells) {
        final nameText = TextChunk.decodeBytes(cell.first.bytes);
        final metaBytes = <int>[];
        for (var k = 1; k < cell.length; k++) {
          metaBytes.addAll(cell[k].bytes);
        }
        final metaText = metaBytes.isEmpty ? '' : TextChunk.decodeBytes(metaBytes);
        final isCourse = periodRe.hasMatch(metaText.trim()) || starRe.hasMatch(nameText);
        anyCourse = anyCourse || isCourse;
        parts.add('$nameText\n$metaText');
      }
      if (!anyCourse) continue;
      courses.addAll(ScheduleParser.parseCell(parts.join('\n'), i + 1, scheduleId));
    }
    return courses;
  }

  /// The first day column's x (星期一) — the 节次 column sits left of it.
  static double _minXOfDayOne(List<List<TextChunk>> rows, int headerRowIdx) {
    for (final c in rows[headerRowIdx]) {
      if (ScheduleParser.dayNumber(c.text.trim()) == 1) return c.x;
    }
    return 100.0;
  }

  static List<List<TextChunk>> clusterRows(List<TextChunk> chunks) {
    final byY = <double, List<TextChunk>>{};
    for (final c in chunks) {
      var key = c.y;
      for (final k in byY.keys) {
        if ((k - c.y).abs() < 8) {
          key = k;
          break;
        }
      }
      byY[key] ??= [];
      byY[key]!.add(c);
    }
    final rows = byY.values.toList();
    rows.sort((a, b) {
      final ay = a.first.y;
      final by = b.first.y;
      return ay.compareTo(by);
    });
    return rows;
  }
}
