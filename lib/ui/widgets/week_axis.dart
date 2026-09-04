import 'package:flutter/material.dart';

/// 周数轴（多时间表）：展示 1..N 周的进度点，点击跳转，当前周高亮。
class WeekAxis extends StatelessWidget {
  final int totalWeeks;
  final int currentWeek;
  final ValueChanged<int> onSelect;

  const WeekAxis({
    super.key,
    required this.totalWeeks,
    required this.currentWeek,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalWeeks,
        itemBuilder: (context, i) {
          final week = i + 1;
          final selected = week == currentWeek;
          return InkWell(
            onTap: () => onSelect(week),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: selected
                    ? Border.all(color: scheme.primary, width: 1.2)
                    : null,
              ),
              child: Text(
                '$week',
                style: TextStyle(
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}