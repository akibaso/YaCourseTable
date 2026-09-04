import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/weeks.dart';

/// Google Calendar 风格“日视图”：
/// - 左侧时间轴（7:00–23:00，每小时一行）
/// - 顶部星期表头（周一..周日 + 当周具体日期）
/// - 课程卡片按真实钟点时间定位（PeriodTime）
/// - 当前时间红色指示线（仅在选中周为当前周且列是今天时显示）
/// 高性能：单个纵向滚动 + 普通 Widget 卡片，无嵌套滚动。
class DayView extends StatelessWidget {
  final Schedule schedule;
  final int week;
  final ScrollController? scrollController;

  const DayView({
    super.key,
    required this.schedule,
    required this.week,
    this.scrollController,
  });

  static const double pxPerHour = 48.0;
  static const double gutterWidth = 44.0;
  static const int firstHour = 7;
  static const int lastHour = 23;
  static const double dateBarHeight = 32.0;
  static const double dayHeaderHeight = 32.0;

  /// MD3 调色板（低饱和色调），与 WakeUp 风格一致的柔和色。
  static const List<Color> courseColors = [
    Color(0xFFB3D4FC),
    Color(0xFFCFE3CF),
    Color(0xFFFFE1CC),
    Color(0xFFE7D4F5),
    Color(0xFFFFD6D6),
    Color(0xFFD4F0F0),
  ];

  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contentH = (lastHour - firstHour) * pxPerHour;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = (constraints.maxWidth - gutterWidth) / 7;
        final totalH = DayView.dateBarHeight + DayView.dayHeaderHeight + contentH;
        return SingleChildScrollView(
          controller: scrollController,
          child: SizedBox(
            width: constraints.maxWidth,
            height: totalH,
            child: Column(
              children: [
                _buildDateBar(context, scheme),
                _buildDayHeaders(context, dayWidth),
                Row(
                  children: [
                    SizedBox(
                      width: gutterWidth,
                      height: contentH,
                      child: _buildTimeGutter(context, scheme),
                    ),
                    for (var d = 0; d < 7; d++)
                      SizedBox(
                        width: dayWidth,
                        height: contentH,
                        child: _buildDayColumn(context, d, dayWidth, scheme),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 顶部日期条（类似 Google Calendar 的 “9月4日 星期五”）。
  Widget _buildDateBar(BuildContext context, ColorScheme scheme) {
    final monday = _mondayOfWeek();
    return SizedBox(
      height: DayView.dateBarHeight,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '${monday.month}月${monday.day}日 周${_dayNames[monday.weekday - 1]}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '第 $week 周',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  /// 星期表头行：周一..周日 + 当周日期（M/D）。
  Widget _buildDayHeaders(BuildContext context, double dayWidth) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: DayView.dayHeaderHeight,
      child: Row(
        children: [
          const SizedBox(width: gutterWidth),
          for (var d = 0; d < 7; d++)
            SizedBox(
              width: dayWidth,
              child: Center(
                child: Text(
                  '周${_dayNames[d]} ${_dateOf(d + 1)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: d == DateTime.now().weekday - 1 ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: d == DateTime.now().weekday - 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 左侧时间轴：整点小时标签 + 上午/下午/晚上 分组标签。
  Widget _buildTimeGutter(BuildContext context, ColorScheme scheme) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final groupStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (var h = firstHour; h < lastHour; h++)
          Positioned(
            top: (h - firstHour) * pxPerHour - 7,
            left: 0,
            child: Text('$h:00', style: labelStyle),
          ),
        Positioned(
          top: (8 - firstHour) * pxPerHour + 4,
          left: 0,
          child: Text('上午', style: groupStyle),
        ),
        Positioned(
          top: (14 - firstHour) * pxPerHour + 4,
          left: 0,
          child: Text('下午', style: groupStyle),
        ),
        Positioned(
          top: (19 - firstHour) * pxPerHour + 4,
          left: 0,
          child: Text('晚上', style: groupStyle),
        ),
      ],
    );
  }

  /// 单列（某天）：背景时间网格线（CustomPaint）+ 按钟点定位的课程卡片 + 当前时间线。
  Widget _buildDayColumn(BuildContext context, int d, double dayWidth, ColorScheme scheme) {
    final contentH = (lastHour - firstHour) * pxPerHour;
    final day = d + 1;
    final courses = Weeks.coursesForDay(schedule, week, day);
    final now = DateTime.now();
    final isCurrentWeek =
        Weeks.currentWeek(DateTime.parse(schedule.semesterStartIso), now) == week;
    final isToday = day == now.weekday;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        CustomPaint(
          size: Size(dayWidth, contentH),
          painter: _DayLinesPainter(
            firstHour: firstHour,
            lastHour: lastHour,
            pxPerHour: pxPerHour,
            lineColor: scheme.outlineVariant,
          ),
        ),
        for (final course in courses)
          for (final slot in course.timeSlots)
            if (slot.dayOfWeek == day && Weeks.weekInRange(week, slot.weekSpec))
              _courseCard(context, course, slot, dayWidth, scheme),
        if (isCurrentWeek && isToday)
          _nowIndicator(context, scheme),
      ],
    );
  }

  /// 课程卡片：按 PeriodTime 的钟点时间定位。
  Widget _courseCard(BuildContext context, Course course, TimeSlot slot, double dayWidth, ColorScheme scheme) {
    final times = schedule.periodTimes;
    if (slot.startPeriod < 1 || slot.startPeriod > times.length) return const SizedBox.shrink();
    if (slot.endPeriod < slot.startPeriod || slot.endPeriod > times.length) {
      return const SizedBox.shrink();
    }
    final startMin = times[slot.startPeriod - 1].startMin;
    final endMin = times[slot.endPeriod - 1].endMin;
    final top = (startMin - firstHour * 60) / 60 * pxPerHour;
    final height = math.max((endMin - startMin) / 60 * pxPerHour, 24.0);
    final color = courseColors[course.id.hashCode.abs() % courseColors.length];

    final textLines = [
      course.name,
      if (slot.weekSpec.describe().isNotEmpty) slot.weekSpec.describe(),
    ];
    return Positioned(
      top: top,
      left: 3,
      width: dayWidth - 6,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                textLines.join('\n'),
                maxLines: height > 52 ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Color(0xFF1B1B1F),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (height > 64 && (course.venue != null || course.teacher != null))
              Text(
                [course.venue, course.teacher].whereType<String>().join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF1B1B1F).withValues(alpha: 0.7),
                    ),
              ),
          ],
        ),
      ),
    );
  }

  /// 当前时间指示线（红色，Google Calendar 风格）。
  Widget _nowIndicator(BuildContext context, ColorScheme scheme) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    if (nowMin < firstHour * 60 || nowMin > lastHour * 60) {
      return const SizedBox.shrink();
    }
    final top = (nowMin - firstHour * 60) / 60 * pxPerHour;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            child: Container(height: 2, color: const Color(0xFFEA4335)),
          ),
          Positioned(
            left: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEA4335),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _mondayOfWeek() {
    final start = DateTime.parse(schedule.semesterStartIso);
    return start.add(Duration(days: (week - 1) * 7));
  }

  String _dateOf(int day) {
    final date = _mondayOfWeek().add(Duration(days: day - 1));
    return '${date.month}/${date.day}';
  }
}

/// 单列背景：整点横线（浅色），用于替代密集的节次网格。
class _DayLinesPainter extends CustomPainter {
  final int firstHour;
  final int lastHour;
  final double pxPerHour;
  final Color lineColor;

  _DayLinesPainter({
    required this.firstHour,
    required this.lastHour,
    required this.pxPerHour,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (var h = firstHour; h < lastHour; h++) {
      final y = (h - firstHour) * pxPerHour;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DayLinesPainter old) =>
      old.lineColor != lineColor || old.pxPerHour != pxPerHour;
}
