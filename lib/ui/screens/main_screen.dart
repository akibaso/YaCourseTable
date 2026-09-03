import 'package:flutter/material.dart';

/// Main timetable screen. Full implementation lands in Task 4;
/// this skeleton keeps the app booting and gives CI something to analyze.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('YaCourseTable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加课程',
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.file_download),
            tooltip: '导入课表',
            onPressed: () {},
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 64, color: scheme.primary),
            const SizedBox(height: 12),
            Text('课表加载中…', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
