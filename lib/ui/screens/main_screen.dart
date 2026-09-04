import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';

import 'import_screen.dart';

/// 主界面：周课表网格（Task 4 完整网格在此之后填充）。
/// 当前提供：顶部工具栏（添加/导入/导出/更多）、多课表切换器、周数轴骨架。
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(appDataProvider);
    final data = dataAsync.value ?? AppData();
    final schedule = data.activeSchedule();

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
      body: dataAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month, size: 64, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    '周数轴 / 课表网格（Task 4）',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  if (data.schedules.length > 1)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in data.schedules)
                          ActionChip(
                            label: Text(s.name),
                            backgroundColor: s.id == schedule?.id
                                ? scheme.secondaryContainer
                                : null,
                            onPressed: () {
                              ref.read(appDataProvider.notifier).setActiveSchedule(s.id);
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}