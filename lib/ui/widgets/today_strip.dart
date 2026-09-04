import 'package:flutter/material.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/weeks.dart';

/// 今日课程条（今日视图）：把今天的每门课的 名称/时间/老师/地址 横向排开，一目了然。
class TodayStrip extends StatelessWidget {
  final Schedule schedule;
  final int week;
  final WeekPlan? plan;

  const TodayStrip({super.key, required this.schedule, required this.week, this.plan});

  static String _fmtTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final scale = schedule.settings.fontSizeScale;
    final today = DateTime.now().weekday; // 1=周一
    final items = _todayClasses(schedule, week, today, plan);
    if (items.isEmpty) return const SizedBox.shrink();
    final timeStyle = t.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10 * scale);
    final nameStyle = t.labelMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
      fontSize: 14 * scale,
    );
    final infoStyle = t.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10 * scale);

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final course = items[i].$1;
          final info = [
            if (course.teacher != null) course.teacher!,
            if (course.venue != null) course.venue!,
          ].join(' · ');
          final timeRange =
              '${_fmtTime(items[i].$2)}-${_fmtTime(items[i].$3)}';
          return Container(
            width: 180,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeRange,
                  style: timeStyle,
                ),
                const SizedBox(height: 2),
                Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle,
                ),
                if (info.isNotEmpty)
                  Text(
                    info,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: infoStyle,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static List<(Course, int, int)> _todayClasses(Schedule schedule, int week, int day, WeekPlan? plan) {
    final times = schedule.periodTimes;
    final result = <(Course, int, int)>[];
    for (final (course, slot) in Weeks.slotsForWeek(schedule, week)) {
      if (slot.dayOfWeek == day && _slotVisibleInPlan(slot, week, plan)) {
        result.add((course, times[slot.startPeriod - 1].startMin, times[slot.endPeriod - 1].endMin));
      }
    }
    result.sort((a, b) => a.$2.compareTo(b.$2));
    return result;
  }

  /// 选中多时间表后，只展示课程周次与时间表周范围有交叠的课程。
  static bool _slotVisibleInPlan(TimeSlot slot, int week, WeekPlan? plan) {
    if (plan == null) return true;
    if (!Weeks.weekInPlan(week, plan)) return false;
    for (var w = plan.weekStart; w <= plan.weekEnd; w++) {
      if (!Weeks.weekInPlan(w, plan)) continue;
      if (slot.weekSpec.contains(w)) return true;
    }
    return false;
  }
}
