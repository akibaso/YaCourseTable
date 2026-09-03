/// Week specification for a course time slot: which weeks the course runs,
/// with optional odd/even restriction (单双周).
class WeekSpec {
  /// Ranges like [[2,5],[7,12]] flattened: start/end week pairs.
  final List<int> weeks;
  final String oddEven; // 'all' | 'odd' | 'even'

  WeekSpec({required this.weeks, this.oddEven = 'all'});

  bool contains(int week) {
    for (var i = 0; i + 1 < weeks.length; i += 2) {
      final start = weeks[i];
      final end = weeks[i + 1];
      if (week >= start && week <= end) {
        if (oddEven == 'odd' && week.isEven) return false;
        if (oddEven == 'even' && week.isOdd) return false;
        return true;
      }
    }
    return false;
  }

  String describe() {
    final ranges = <String>[];
    for (var i = 0; i + 1 < weeks.length; i += 2) {
      ranges.add(
        weeks[i] == weeks[i + 1]
            ? '${weeks[i]}周'
            : '${weeks[i]}-${weeks[i + 1]}周',
      );
    }
    final parity = oddEven == 'odd' ? '(单)' : (oddEven == 'even' ? '(双)' : '');
    return ranges.join(',') + parity;
  }
}

/// A single day/period window of a course.
class TimeSlot {
  /// 1 = 星期一 … 7 = 星期日.
  final int dayOfWeek;
  final int startPeriod;
  final int endPeriod;
  final WeekSpec weekSpec;

  TimeSlot({
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
    WeekSpec? weekSpec,
  }) : weekSpec = weekSpec ?? WeekSpec(weeks: [1, 1]);

  static TimeSlot fromJson(Map<String, dynamic> json) {
    final ws = json['weekSpec'];
    WeekSpec spec;
    if (ws is Map) {
      final weeks = (ws['weeks'] as List).map((e) => (e as num).toInt()).toList();
      spec = WeekSpec(weeks: weeks, oddEven: (ws['oddEven'] ?? 'all') as String);
    } else {
      spec = WeekSpec(weeks: [1, 1]);
    }
    return TimeSlot(
      dayOfWeek: (json['dayOfWeek'] as num).toInt(),
      startPeriod: (json['startPeriod'] as num).toInt(),
      endPeriod: (json['endPeriod'] as num).toInt(),
      weekSpec: spec,
    );
  }

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'startPeriod': startPeriod,
        'endPeriod': endPeriod,
        'weekSpec': {
          'weeks': weekSpec.weeks,
          'oddEven': weekSpec.oddEven,
        },
      };
}

/// A course with one or more time slots.
class Course {
  final String id;
  final String scheduleId;
  final String name;
  final String? teacher;
  final String? venue;
  final String? campus;
  final String? className;
  final String? notes;
  final double? credit;
  final List<TimeSlot> timeSlots;

  Course({
    required this.id,
    required this.scheduleId,
    required this.name,
    this.teacher,
    this.venue,
    this.campus,
    this.className,
    this.notes,
    this.credit,
    List<TimeSlot>? timeSlots,
  }) : timeSlots = timeSlots ?? [];

  static Course fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      scheduleId: json['scheduleId'] as String,
      name: json['name'] as String,
      teacher: json['teacher'] as String?,
      venue: json['venue'] as String?,
      campus: json['campus'] as String?,
      className: json['className'] as String?,
      notes: json['notes'] as String?,
      credit: (json['credit'] as num?)?.toDouble(),
      timeSlots: (json['timeSlots'] as List?)
          ?.map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scheduleId': scheduleId,
        'name': name,
        'teacher': teacher,
        'venue': venue,
        'campus': campus,
        'className': className,
        'notes': notes,
        'credit': credit,
        'timeSlots': timeSlots.map((s) => s.toJson()).toList(),
      };
}

/// A named week plan (多时间表): a contiguous or ranged set of weeks.
class WeekPlan {
  final String id;
  final String name;
  final int weekStart;
  final int weekEnd;
  final String oddEven;

  WeekPlan({
    required this.id,
    required this.name,
    required this.weekStart,
    required this.weekEnd,
    this.oddEven = 'all',
  });

  static WeekPlan fromJson(Map<String, dynamic> json) {
    return WeekPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      weekStart: (json['weekStart'] as num).toInt(),
      weekEnd: (json['weekEnd'] as num).toInt(),
      oddEven: (json['oddEven'] ?? 'all') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'oddEven': oddEven,
      };
}

class ScheduleSettings {
  final String background;
  final double fontSizeScale;

  ScheduleSettings({this.background = 'auto', this.fontSizeScale = 1.0});

  static ScheduleSettings fromJson(Map<String, dynamic> json) =>
      ScheduleSettings(
        background: (json['background'] ?? 'auto') as String,
        fontSizeScale: ((json['fontSizeScale'] as num?) ?? 1.0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'background': background,
        'fontSizeScale': fontSizeScale,
      };
}

class Schedule {
  final String id;
  final String name;
  /// ISO date of semester start (a Monday), e.g. "2026-09-07".
  final String semesterStartIso;
  final int totalWeeks;
  final ScheduleSettings settings;
  final List<Course> courses;
  final List<WeekPlan> weekPlans;

  Schedule({
    required this.id,
    required this.name,
    required this.semesterStartIso,
    this.totalWeeks = 20,
    ScheduleSettings? settings,
    List<Course>? courses,
    List<WeekPlan>? weekPlans,
  })  : settings = settings ?? ScheduleSettings(),
        courses = courses ?? [],
        weekPlans = weekPlans ?? [];

  static Schedule fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] as String,
      name: json['name'] as String,
      semesterStartIso: json['semesterStartIso'] as String,
      totalWeeks: ((json['totalWeeks'] as num?) ?? 20).toInt(),
      settings: json['settings'] == null
          ? ScheduleSettings()
          : ScheduleSettings.fromJson(json['settings'] as Map<String, dynamic>),
      courses: (json['courses'] as List?)
              ?.map((e) => Course.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      weekPlans: (json['weekPlans'] as List?)
              ?.map((e) => WeekPlan.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'semesterStartIso': semesterStartIso,
        'totalWeeks': totalWeeks,
        'settings': settings.toJson(),
        'courses': courses.map((c) => c.toJson()).toList(),
        'weekPlans': weekPlans.map((p) => p.toJson()).toList(),
      };
}

class AppSettings {
  final String themeMode; // 'system' | 'light' | 'dark'
  final int reminderLeadMinutes;
  final bool remindersEnabled;

  AppSettings({
    this.themeMode = 'system',
    this.reminderLeadMinutes = 5,
    this.remindersEnabled = true,
  });

  static AppSettings fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: (json['themeMode'] ?? 'system') as String,
        reminderLeadMinutes: ((json['reminderLeadMinutes'] as num?) ?? 5).toInt(),
        remindersEnabled: (json['remindersEnabled'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode,
        'reminderLeadMinutes': reminderLeadMinutes,
        'remindersEnabled': remindersEnabled,
      };
}

/// Root document: multiple schedules (多课表), each with independent
/// settings and week plans (多时间表).
class AppData {
  final String activeScheduleId;
  final String activeWeekPlanId;
  final List<Schedule> schedules;
  final AppSettings settings;

  AppData({
    String? activeScheduleId,
    String? activeWeekPlanId,
    List<Schedule>? schedules,
    AppSettings? settings,
  })  : activeScheduleId = activeScheduleId ?? '',
        activeWeekPlanId = activeWeekPlanId ?? '',
        schedules = schedules ?? [],
        settings = settings ?? AppSettings();

  Schedule? activeSchedule() {
    for (final s in schedules) {
      if (s.id == activeScheduleId) return s;
    }
    return schedules.isNotEmpty ? schedules.first : null;
  }

  static AppData fromJson(Map<String, dynamic> json) {
    return AppData(
      activeScheduleId: json['activeScheduleId'] as String?,
      activeWeekPlanId: json['activeWeekPlanId'] as String?,
      schedules: (json['schedules'] as List?)
              ?.map((e) => Schedule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      settings: json['settings'] == null
          ? AppSettings()
          : AppSettings.fromJson(json['settings'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'activeScheduleId': activeScheduleId,
        'activeWeekPlanId': activeWeekPlanId,
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'settings': settings.toJson(),
      };
}

extension IntExt on int {
  bool get isOdd => this % 2 == 1;
  bool get isEven => this % 2 == 0;
}
