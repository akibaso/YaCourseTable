import '../core/models.dart';

/// Normalizes a timetable "cell" text (stacked courses) into [Course] objects.
///
/// Cell text looks like (教务系统导出):
///   模拟电子技术*
///   (1-2节)1-5周,7-12周/校区:南望山校区/场地:教三楼706/教师:葛健/教学班:模拟电子技术-0002/.../学分:3.0
///   数字电子技术*
///   (3-4节)9-16周/...
class ScheduleParser {
  /// Maps a day-of-week header (full 星期一..星期日 or short 周一..周日)
  /// to a 1-based day number (1 = Monday .. 7 = Sunday). Returns null if
  /// the header is not a recognized day name.
  static int? dayNumber(String header) {
    const full = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    const short = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    // The cell may carry a wrapped "星期日\n上午" — check the first word.
    var first = header.trim();
    if (first.contains('\n')) first = first.split('\n').first.trim();
    var i = full.indexOf(first);
    if (i != -1) return i + 1;
    i = short.indexOf(first);
    if (i != -1) return i + 1;
    return null;
  }

  static final _periodRe = RegExp(r'^\((\d+)-(\d+)节\)');
  static final _kwRe = RegExp(r'(\d+)-(\d+)节');
  static final _weekRangeRe = RegExp(r'(\d+)-(\d+)周');
  static final _weekSingleRe = RegExp(r'(?<![\d-])(\d+)周');
  static final _kv = {
    'campus': RegExp(r'校区:([^/]*)'),
    'venue': RegExp(r'场地:([^/]*)'),
    'teacher': RegExp(r'教师:([^/]*)'),
    'className': RegExp(r'教学班:([^/]*)'),
    'credit': RegExp(r'学分:([^/]*)'),
  };

  /// Split stacked-course cell text and normalize to courses.
  static List<Course> parseCell(String cellText, int dayOfWeek, String scheduleId) {
    // Works on a cleaned, single-course-per-line text (the PDF parser
    // already splits stacked cells and joins each cell's meta into one
    // line). Re-decode any cell text that was joined by an earlier
    // per-line decode (Excel/CSV handle their own line splits).
    final cleaned = <String>[];
    for (final line in cellText.split('\n')) {
      if (line.isEmpty) continue;
      cleaned.add(line);
    }
    final blocks = <List<String>>[];
    var current = <String>[];
    for (final line in cleaned) {
      if (current.isEmpty) {
        // First line of a block = the course name.
        current = [line];
        continue;
      }
      final startsPeriod = line.startsWith('(');
      final looksName = startsPeriod
          ? false
          : (_periodRe.hasMatch(line) == false &&
              (line.contains('*') ||
                  cleaned.length > 1 &&
                      current.length >= 2 &&
                      current.last.startsWith('(')));
      if (current.length >= 2 && !startsPeriod && looksName) {
        // A new stacked course name (not a meta line).
        blocks.add(current);
        current = [line];
      } else if (startsPeriod && current.length > 1) {
        // The period line of a new stacked course AFTER the current one's
        // meta — close the previous block.
        blocks.add(current);
        current = [line];
      } else if (startsPeriod) {
        // The period line of the current course.
        current.add(line);
      } else {
        // Meta line of the current course.
        current.add(line);
      }
    }
    if (current.isNotEmpty) blocks.add(current);

    // Merge a glued name: when a cell's name line ends up merged with the
    // next cell's period line (PDF two-line cells), the name block is a
    // single "A* (x-y节)..." line with no "(" at line start. Split it here.
    final fixed = <List<String>>[];
    for (final block in blocks) {
      if (block.length == 1) {
        final line = block.first;
        final km = _kwRe.firstMatch(line);
        if (km != null && km.start > 0) {
          fixed.add([line.substring(0, km.start).trim()]);
          fixed.add([line.substring(km.start)]);
          continue;
        }
      }
      fixed.add(block);
    }

    final courses = <Course>[];
    for (final block in fixed) {
      var name = block.first;
      // Join meta lines with no separator: PDF/Excel cells can split a
      // label (教师) from its value (:葛健) across lines; empty join makes
      // "教师:葛健" contiguous so the key/value regexes match.
      var meta = block.length > 1 ? block.sublist(1).join('') : '';

      var startPeriod = 1;
      var endPeriod = 2;
      final pm = _periodRe.firstMatch(meta);
      if (pm != null) {
        startPeriod = int.parse(pm.group(1)!);
        endPeriod = int.parse(pm.group(2)!);
      } else {
        // The cell had no "(x-y节)" marker — typically a cell whose name
        // line ended up glued to the following cell's period line. The meta
        // then contains a "x-y节" marker mid-string with the real course meta
        // after it. Split at the LAST such marker so this cell keeps its own
        // period + meta, instead of leaking into the next cell.
        final all = _kwRe.allMatches(meta).toList();
        final km = all.isNotEmpty ? all.last : null;
        if (km != null && km.start > 0) {
          final idx = km.start;
          final namePart = meta.substring(0, idx).trim();
          final metaPart = meta.substring(idx);
          var newName = name;
          if (namePart.isNotEmpty) {
            // The glued name is "<thisName> <nextName>"; keep this cell's
            // name, but strip a trailing sequence of a single CJK char run
            // that is the next course's name (e.g. 线 from 线性代数B*).
            var candidate = namePart;
            final mStrip = RegExp(r'[\u4e00-\u9fff]$').firstMatch(candidate);
            if (mStrip != null && candidate.length > 1) {
              candidate = candidate.substring(0, candidate.length - 1);
            }
            if (candidate.trim().isNotEmpty) newName = candidate.trim();
          }
          name = newName;
          meta = metaPart;
          final pm2 = _periodRe.firstMatch(meta);
          if (pm2 != null) {
            startPeriod = int.parse(pm2.group(1)!);
            endPeriod = int.parse(pm2.group(2)!);
          }
        }
      }

      final weeks = <int>[];
      final seen = <int>{};
      for (final m in _weekRangeRe.allMatches(meta)) {
        for (var w = int.parse(m.group(1)!); w <= int.parse(m.group(2)!); w++) {
          if (seen.add(w)) weeks.add(w);
        }
      }
      for (final m in _weekSingleRe.allMatches(meta)) {
        final w = int.parse(m.group(1)!);
        if (!seen.contains(w)) {
          seen.add(w);
          weeks.add(w);
        }
      }
      weeks.sort();
      final spec = WeekSpec(
        weeks: _toRangePairs(weeks),
        oddEven: meta.contains('(单)') ? 'odd' : (meta.contains('(双)') ? 'even' : 'all'),
      );

      Course course = Course(
        id: 'pdf_${dayOfWeek}_${startPeriod}_$name',
        scheduleId: scheduleId,
        name: name,
        timeSlots: [
          TimeSlot(
            dayOfWeek: dayOfWeek,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            weekSpec: spec,
          )
        ],
      );

      for (final entry in _kv.entries) {
        final m = entry.value.firstMatch(meta);
        if (m == null) continue;
        final value = m.group(1)?.trim();
        if (value == null || value.isEmpty || value == '未安排') continue;
        switch (entry.key) {
          case 'campus':
            course = _withCampus(course, value);
            break;
          case 'venue':
            course = _withVenue(course, value);
            break;
          case 'teacher':
            course = _withTeacher(course, value);
            break;
          case 'className':
            course = _withClassName(course, value);
            break;
          case 'credit':
            course = _withCredit(course, double.tryParse(value));
            break;
        }
      }
      courses.add(course);
    }
    return courses;
  }

  /// [weeks] is a sorted list of week numbers; group consecutive runs into
  /// [start, end] pairs for WeekSpec (which stores flattened start/end pairs).
  static List<int> _toRangePairs(List<int> weeks) {
    if (weeks.isEmpty) return [];
    final pairs = <int>[];
    var i = 0;
    while (i < weeks.length) {
      var j = i;
      while (j + 1 < weeks.length && weeks[j + 1] == weeks[j] + 1) {
        j++;
      }
      pairs.add(weeks[i]);
      pairs.add(weeks[j]);
      i = j + 1;
    }
    return pairs;
  }

  // Course fields are final; rebuild with the new value (immutable domain model).
  static Course _withCampus(Course c, String v) => _rebuild(c, campus: v);
  static Course _withVenue(Course c, String v) => _rebuild(c, venue: v);
  static Course _withTeacher(Course c, String v) => _rebuild(c, teacher: v);
  static Course _withClassName(Course c, String v) => _rebuild(c, className: v);
  static Course _withCredit(Course c, double? v) => _rebuild(c, credit: v);

  static Course _rebuild(
    Course c, {
    String? campus,
    String? venue,
    String? teacher,
    String? className,
    double? credit,
  }) {
    return Course(
      id: c.id,
      scheduleId: c.scheduleId,
      name: c.name,
      teacher: teacher ?? c.teacher,
      venue: venue ?? c.venue,
      campus: campus ?? c.campus,
      className: className ?? c.className,
      notes: c.notes,
      credit: credit ?? c.credit,
      timeSlots: c.timeSlots,
    );
  }
}
