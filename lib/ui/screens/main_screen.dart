import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/weeks.dart';
import 'package:ya_coursetable/ui/widgets/day_view.dart';
import 'package:ya_coursetable/ui/widgets/schedule_switcher.dart';
import 'package:ya_coursetable/ui/widgets/week_axis.dart';

import 'add_course_screen.dart';
import 'export_screen.dart';
import 'import_screen.dart';
import 'settings_screen.dart';

/// 主界面（Google Calendar 风格）：
/// - 顶部周数轴（多时间表：选择第 N 周）
/// - 中部“日视图”：时间轴 + 7 天列 + 课程卡片按钟点时间定位 + 当前时间线
/// - 底部多课表切换器（多课表）
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _week = 1;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// “今天”：跳回当前周并滚动到视图顶部（Google Calendar 的“今天”按钮）。
  void _goToday() {
    final data = ref.read(appDataProvider).value ?? AppData();
    final schedule = data.activeSchedule();
    if (schedule == null) return;
    final w = Weeks.currentWeek(DateTime.parse(schedule.semesterStartIso), DateTime.now());
    if (w > 0) setState(() => _week = w);
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = ref.watch(appDataProvider).value ?? AppData();
    final schedule = data.activeSchedule();
    final todayWeek = schedule != null
        ? Weeks.currentWeek(DateTime.parse(schedule.semesterStartIso), DateTime.now())
        : 1;
    final week = todayWeek > 0 ? todayWeek : _week;

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
              onSelect: (w) => setState(() => _week = w),
            ),
          const Divider(height: 1),
          // Google Calendar 风格日视图
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
                : DayView(
                    schedule: schedule,
                    week: week,
                    scrollController: _scroll,
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
        tooltip: '今天',
        onPressed: _goToday,
        child: const Icon(Icons.today),
      ),
    );
  }
}
