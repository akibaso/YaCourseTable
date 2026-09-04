import 'package:flutter/material.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/weeks.dart';

/// 多课表切换器（底部滑轨）：每个课表的缩略图预览，点击切换。
class ScheduleSwitcher extends StatelessWidget {
  final List<Schedule> schedules;
  final String activeId;
  final ValueChanged<String> onSelect;
  final int week;

  const ScheduleSwitcher({
    super.key,
    required this.schedules,
    required this.activeId,
    required this.onSelect,
    this.week = 1,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: schedules.length,
        itemBuilder: (context, i) {
          final s = schedules[i];
          final selected = s.id == activeId;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => onSelect(s.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: selected ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${s.courses.length} 门课',
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? scheme.onSecondaryContainer.withValues(alpha: 0.7)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _nextClass(s, week),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? scheme.onSecondaryContainer.withValues(alpha: 0.7)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _nextClass(Schedule s, int week) {
    final today = DateTime.now().weekday;
    for (var d = 0; d < 7; d++) {
      final day = (today - 1 + d) % 7 + 1;
      final courses = Weeks.coursesForDay(s, week, day);
      if (courses.isNotEmpty) {
        return courses.first.name;
      }
    }
    return '';
  }
}