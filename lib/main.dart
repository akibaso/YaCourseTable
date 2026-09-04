import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ya_coursetable/app_theme.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/desktop_widget_service.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/notification_service.dart';
import 'package:ya_coursetable/ui/screens/main_screen.dart';

void main() {
  runApp(
    ProviderScope(
      child: const YaCourseTableApp(),
    ),
  );
}

class YaCourseTableApp extends ConsumerStatefulWidget {
  const YaCourseTableApp({super.key});

  @override
  ConsumerState<YaCourseTableApp> createState() => _YaCourseTableAppState();
}

class _YaCourseTableAppState extends ConsumerState<YaCourseTableApp> {
  @override
  void initState() {
    super.initState();
    _resolveDataPath();
  }

  Future<void> _resolveDataPath() async {
    final dir = await getApplicationSupportDirectory();
    final path = File('${dir.path}/app_data.json').path;
    if (!mounted) return;
    await ref.read(appDataProvider.notifier).setPath(path);
    // 初始化课程提醒通知，并为接下来的课程安排本地通知。
    await NotificationService.init();
    final data = ref.read(appDataProvider).value ?? AppData();
    await NotificationService.syncReminders(data);
    // 启动时同步桌面小部件。
    await DesktopWidgetService.update(data);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider).value;
    final themeMode = data?.settings.themeMode ?? 'system';
    return MaterialApp(
      title: 'YaCourseTable',
      debugShowCheckedModeBanner: false,
      themeMode: AppTheme.themeModeFromName(themeMode),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const MainScreen(),
    );
  }
}