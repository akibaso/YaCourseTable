import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/weeks.dart';
import 'package:ya_coursetable/ui/widgets/schedule_switcher.dart';
import 'package:ya_coursetable/ui/widgets/timetable_grid.dart';
import 'package:ya_coursetable/ui/widgets/week_axis.dart';

import 'import_screen.dart';

/// 主界面：周数轴（多时间表）+ 周课表网格 + 多课表切换器（底部）。
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _week = 1;

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
            onPressed: () {},
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
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: '更多功能',
            onPressed: () {},
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
          // 课表网格
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
                : TimetableGrid(schedule: schedule, week: week),
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
    );
  }
}