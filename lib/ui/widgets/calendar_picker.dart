import 'package:flutter/material.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/weeks.dart';

/// 日历弹窗（Google Calendar 风格）：月份网格，点某天即选中其所在周；
/// 底部“今天”按钮跳回当前周。
class CalendarDialog extends StatefulWidget {
  final Schedule schedule;
  final int initialWeek;
  final ValueChanged<int> onPickWeek;

  const CalendarDialog({
    super.key,
    required this.schedule,
    required this.initialWeek,
    required this.onPickWeek,
  });

  @override
  State<CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<CalendarDialog> {
  late DateTime _month;
  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final start = DateTime.parse(widget.schedule.semesterStartIso);
    final monday = start.add(Duration(days: (widget.initialWeek - 1) * 7));
    _month = DateTime(monday.year, monday.month, 1);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  int _daysInMonth() {
    final next = DateTime(_month.year, _month.month + 1, 0);
    return next.day;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final semesterStart = DateTime.parse(widget.schedule.semesterStartIso);
    final totalWeeks = widget.schedule.totalWeeks;
    final today = DateTime.now();

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: '上个月',
                  onPressed: () => _shiftMonth(-1),
                ),
                Text(
                  '${_month.year}年${_month.month}月',
                  style: t.titleMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: '下个月',
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 星期表头
            Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: Center(
                      child: Text(
                        _dayNames[d],
                        style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _buildMonthGrid(scheme, semesterStart, totalWeeks, today),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                final w = Weeks.currentWeek(semesterStart, DateTime.now());
                final week = w > 0 ? w : 1;
                final clamped = week > totalWeeks ? totalWeeks : week;
                widget.onPickWeek(clamped);
                Navigator.of(context).pop();
              },
              child: const Text('今天'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(ColorScheme scheme, DateTime semesterStart, int totalWeeks, DateTime today) {
    final t = Theme.of(context).textTheme;
    final first = DateTime(_month.year, _month.month, 1);
    final days = _daysInMonth();
    final leadingBlanks = (first.weekday + 5) % 7; // 周从周一起始
    final totalCells = leadingBlanks + days;
    final rowCount = (totalCells + 6) ~/ 7;

    final rows = <Widget>[];
    for (var r = 0; r < rowCount; r++) {
      final cells = <Widget>[];
      for (var c = 0; c < 7; c++) {
        final idx = r * 7 + c;
        if (idx < leadingBlanks || idx >= totalCells) {
          cells.add(Expanded(child: const SizedBox(height: 40)));
          continue;
        }
        final dayNum = idx - leadingBlanks + 1;
        final d = DateTime(_month.year, _month.month, dayNum);
        final diff = d.difference(semesterStart).inDays;
        final weekNo = diff >= 0 ? diff ~/ 7 + 1 : 0;
        final inSemester = weekNo >= 1 && weekNo <= totalWeeks;
        final isToday =
            d.year == today.year && d.month == today.month && d.day == today.day;
        cells.add(
          Expanded(
            child: InkWell(
              onTap: inSemester
                  ? () {
                      widget.onPickWeek(weekNo);
                      Navigator.of(context).pop();
                    }
                  : null,
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: inSemester ? scheme.secondaryContainer : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday ? Border.all(color: scheme.primary, width: 2) : null,
                  ),
                  child: Text(
                    '$dayNum',
                    style: t.labelMedium?.copyWith(
                      color: inSemester ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      rows.add(Row(children: cells));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}
