import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/app_theme.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/weeks.dart';
import 'package:ya_coursetable/ui/widgets/calendar_picker.dart';
import 'package:ya_coursetable/ui/widgets/day_view.dart';
import 'package:ya_coursetable/ui/widgets/schedule_switcher.dart';
import 'package:ya_coursetable/ui/widgets/today_strip.dart';
import 'package:ya_coursetable/ui/widgets/week_axis.dart';

import 'add_course_screen.dart';
import 'export_screen.dart';
import 'import_screen.dart';
import 'settings_screen.dart';

/// 主界面（Google Calendar 风格）：
/// - 顶部周数轴（多时间表：选择第 N 周）
/// - 今日课程条（今日视图：名称/时间/老师/地址一目了然）
/// - 中部“日视图”：左右滑动切换周（PageView），时间轴 + 7 天列 + 课程卡片
/// - 底部多课表切换器（多课表）
/// - 右下角日历 FAB：打开月份网格选择周
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final PageController _pageCtrl = PageController();
  final ScrollController _scroll = ScrollController();
  int _page = 0; // PageView 页码（0 基，周 = page+1）
  int? _pinnedWeek; // 用户显式选定的周（周数轴/日历弹窗），滑动切换时清除
  String? _activeScheduleId;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int get _selectedWeek => _pinnedWeek ?? (_page + 1);

  void _onWeekAxisSelect(int w) {
    setState(() {
      _page = w - 1;
      _pinnedWeek = w;
    });
    _pageCtrl.animateToPage(w - 1, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _openCalendar() async {
    final data = ref.read(appDataProvider).value ?? AppData();
    final schedule = data.activeSchedule();
    if (schedule == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => CalendarDialog(
        schedule: schedule,
        initialWeek: _selectedWeek,
        onPickWeek: (w) {
          if (!mounted) return;
          setState(() {
            _page = w - 1;
            _pinnedWeek = w;
          });
          _pageCtrl.animateToPage(w - 1, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        },
      ),
    );
  }

  /// 课表背景设置（auto 跟随系统 / light / dark）：覆盖日视图主题。
  static Widget _applyScheduleBackground(Widget view, String background) {
    switch (background) {
      case 'light':
        return Theme(data: AppTheme.light(), child: view);
      case 'dark':
        return Theme(data: AppTheme.dark(), child: view);
      default:
        return view;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 数据首次就绪或活动课表切换时，跳到该课表的当前周（类似 Google Calendar）。
    ref.listen(appDataProvider, (prev, next) {
      final data = next.value ?? AppData();
      if (data.activeScheduleId != _activeScheduleId) {
        _activeScheduleId = data.activeScheduleId;
        final schedule = data.activeSchedule();
        if (schedule != null) {
          final w = Weeks.currentWeek(DateTime.parse(schedule.semesterStartIso), DateTime.now());
          final clamped = w > 0 ? math.min(w, schedule.totalWeeks) : 1;
          _page = clamped - 1;
          _pinnedWeek = clamped;
          if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(_page);
          if (mounted) setState(() {});
        }
      }
    });

    final scheme = Theme.of(context).colorScheme;
    final data = ref.watch(appDataProvider).value ?? AppData();
    final schedule = data.activeSchedule();
    final week = _selectedWeek;
    final totalWeeks = schedule?.totalWeeks ?? 1;

    // 今日课程条仅在“显示的周 == 学期当前周”时展示（今日视图）。
    final isCurrentWeek = schedule != null &&
        week == math.max(
            Weeks.currentWeek(DateTime.parse(schedule.semesterStartIso), DateTime.now()), 1);

    // 活动的多时间表（WeekPlan）：选中后主界面只显示其周范围内的课程。
    WeekPlan? activePlan;
    if (schedule != null && data.activeWeekPlanId.isNotEmpty) {
      for (final p in schedule.weekPlans) {
        if (p.id == data.activeWeekPlanId) {
          activePlan = p;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(schedule?.name ?? 'YaCourseTable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加课程',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddCourseScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.file_download),
            tooltip: '导入课表',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.file_upload),
            tooltip: '导出课表',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: '更多功能',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 周数轴（多时间表）
          if (schedule != null)
            WeekAxis(
              totalWeeks: schedule.totalWeeks,
              currentWeek: week,
              onSelect: _onWeekAxisSelect,
            ),
          const Divider(height: 1),
          // 今日课程条（今日视图：名称/时间/老师/地址一目了然）
          if (schedule != null && isCurrentWeek)
            TodayStrip(schedule: schedule, week: week, plan: activePlan),
          // Google Calendar 风格日视图：左右滑动切换周
          Expanded(
            child: schedule == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month, size: 64, color: scheme.primary),
                        const SizedBox(height: 12),
                        Text('还没有课表，点击右上角“导入课表”开始',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : PageView(
                    controller: _pageCtrl,
                    physics: const PageScrollPhysics(),
                    onPageChanged: (page) => setState(() {
                      _page = page;
                      _pinnedWeek = null;
                    }),
                    children: [
                      for (var w = 1; w <= totalWeeks; w++)
                        _applyScheduleBackground(
                          DayView(
                            schedule: schedule,
                            week: w,
                            scrollController: w == week ? _scroll : null,
                            plan: activePlan,
                          ),
                          schedule.settings.background,
                        ),
                    ],
                  ),
          ),
          // 多课表切换器
          if (data.schedules.length > 1)
            ScheduleSwitcher(
              schedules: data.schedules,
              activeId: data.activeScheduleId,
              week: week,
              onSelect: (id) {
                ref.read(appDataProvider.notifier).setActiveSchedule(id);
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '选择周',
        onPressed: _openCalendar,
        child: const Icon(Icons.calendar_month),
      ),
    );
  }
}
