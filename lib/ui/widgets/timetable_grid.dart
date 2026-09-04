import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/weeks.dart';

/// 周课表网格：7 天 × 节次的 CustomPainter 绘制（高性能，非 N 个独立 Widget）。
///
/// 布局：
/// - 左侧时间轴（节次 1..12 + 上午/下午/晚上 分组标签）
/// - 顶部星期表头（周一..周日 + 当周日期）
/// - 课程格子：同一时间段可堆叠多门课程，课程卡片显示名称/场地/教师
class TimetableGrid extends StatelessWidget {
  final Schedule schedule;
  final int week;
  final List<Color> courseColors;

  static const double periodHeight = 52;
  static const double timeAxisWidth = 44;
  static const double headerHeight = 36;

  const TimetableGrid({
    super.key,
    required this.schedule,
    required this.week,
    this.courseColors = const [
      Color(0xFFB3D4FC),
      Color(0xFFCFE3CF),
      Color(0xFFFFE1CC),
      Color(0xFFE7D4F5),
      Color(0xFFFFD6D6),
      Color(0xFFD4F0F0),
    ],
  });

  static const int maxPeriod = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = (constraints.maxWidth - timeAxisWidth) / 7;
        final gridHeight = maxPeriod * periodHeight;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: timeAxisWidth + dayWidth * 7,
            child: SingleChildScrollView(
              child: SizedBox(
                height: gridHeight + headerHeight,
                child: CustomPaint(
                  size: Size(timeAxisWidth + dayWidth * 7, gridHeight + headerHeight),
                  painter: _GridPainter(
                    schedule: schedule,
                    week: week,
                    dayWidth: dayWidth,
                    courseColors: courseColors,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final Schedule schedule;
  final int week;
  final double dayWidth;
  final List<Color> courseColors;

  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  _GridPainter({
    required this.schedule,
    required this.week,
    required this.dayWidth,
    required this.courseColors,
  });

  /// 该周第 [day]（1=周一）的日期字符串。
  String _dateOf(int day) {
    final start = DateTime.parse(schedule.semesterStartIso);
    final date = start.add(Duration(days: (week - 1) * 7 + (day - 1)));
    return '${date.month}/${date.day}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final timeAxisWidth = TimetableGrid.timeAxisWidth;
    final headerHeight = TimetableGrid.headerHeight;
    final periodHeight = TimetableGrid.periodHeight;

    // 背景
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _bg,
    );

    // 顶部星期表头 + 日期
    for (var d = 0; d < 7; d++) {
      final x = timeAxisWidth + d * dayWidth;
      final rect = Rect.fromLTWH(x, 0, dayWidth, headerHeight);
      canvas.drawRect(
        rect,
        Paint()..color = d.isEven ? _headerEven : _headerOdd,
      );
      _text(
        canvas,
        '周${_dayNames[d]} ${_dateOf(d + 1)}',
        Offset(x + dayWidth / 2, headerHeight / 2),
        center: true,
        color: _headerFg,
        size: 11,
      );
    }

    // 网格线 + 左侧时间轴
    for (var p = 0; p < TimetableGrid.maxPeriod; p++) {
      final y = headerHeight + p * periodHeight;
      canvas.drawLine(
        Offset(timeAxisWidth, y),
        Offset(size.width, y),
        _line,
      );
      // 节次标签
      _text(
        canvas,
        '${p + 1}',
        Offset(timeAxisWidth / 2, y + periodHeight / 2),
        center: true,
        color: _axisFg,
        size: 11,
      );
    }
    for (var d = 0; d <= 7; d++) {
      final x = timeAxisWidth + d * dayWidth;
      canvas.drawLine(
        Offset(x, headerHeight),
        Offset(x, size.height),
        _line,
      );
    }

    // 上午/下午/晚上 分组标签（左侧）
    _text(canvas, '上午', Offset(timeAxisWidth / 2, headerHeight + periodHeight * 2),
        center: true, color: _axisFg, size: 12, bold: true);
    _text(canvas, '下午', Offset(timeAxisWidth / 2, headerHeight + periodHeight * 7),
        center: true, color: _axisFg, size: 12, bold: true);
    _text(canvas, '晚上', Offset(timeAxisWidth / 2, headerHeight + periodHeight * 11),
        center: true, color: _axisFg, size: 12, bold: true);

    // 课程格子
    for (final course in schedule.courses) {
      for (final slot in course.timeSlots) {
        if (!Weeks.weekInRange(week, slot.weekSpec)) continue;
        final d = slot.dayOfWeek - 1;
        if (d < 0 || d > 6) continue;
        final top = headerHeight + (slot.startPeriod - 1) * periodHeight;
        final height =
            math.max((slot.endPeriod - slot.startPeriod) * periodHeight, periodHeight);
        final rect = Rect.fromLTWH(timeAxisWidth + d * dayWidth + 2, top + 2,
            dayWidth - 4, height - 4);
        _drawCourse(canvas, rect, course, slot);
      }
    }
  }

  void _drawCourse(
      Canvas canvas, Rect rect, Course course, TimeSlot slot) {
    final color = courseColors[course.id.hashCode.abs() % courseColors.length];
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final radius = Radius.circular(6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 课程名（多行省略）
    final text = course.name + (slot.weekSpec.describe().isNotEmpty ? '\n${slot.weekSpec.describe()}' : '');
    _text(
      canvas,
      text,
      rect.topLeft + Offset(6, 4),
      color: _courseFg,
      size: 11,
      maxWidth: rect.width - 12,
      lines: (rect.height / 14).floor().clamp(1, 6),
    );
    if (course.venue != null && rect.height > 40) {
      _text(
        canvas,
        course.venue!,
        rect.topLeft + Offset(6, rect.height - 16),
        color: _courseFg.withValues(alpha: 0.75),
        size: 10,
        maxWidth: rect.width - 12,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    bool center = false,
    Color color = Colors.black87,
    double size = 12,
    bool bold = false,
    double? maxWidth,
    int lines = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    final offset = center
        ? at - Offset(painter.width / 2, painter.height / 2)
        : at;
    painter.paint(canvas, offset);
  }

  static const _bg = Color(0xFFFAFAFC);
  static const _headerEven = Color(0xFFE3EAF9);
  static const _headerOdd = Color(0xFFEFF3FB);
  static const _headerFg = Color(0xFF2C3A5E);
  static const _axisFg = Color(0xFF8A94A6);
  static const _courseFg = Color(0xFF1B1B1F);
  static final _line = Paint()
    ..color = const Color(0xFFE4E7EE)
    ..strokeWidth = 1;

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.schedule != schedule || old.week != week || old.dayWidth != dayWidth;
}