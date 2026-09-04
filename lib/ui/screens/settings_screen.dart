import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/core/notification_service.dart';
import 'package:ya_coursetable/ui/screens/period_times_screen.dart';
import 'package:ya_coursetable/ui/screens/schedules_screen.dart';
import 'package:ya_coursetable/ui/screens/week_plans_screen.dart';

/// 设置（更多功能）：课程提醒开关与提前量、主题模式（MD3 控件）。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider).value ?? AppData();
    final settings = data.settings;
    final scheme = Theme.of(context).colorScheme;

    Future<void> update(AppSettings s) async {
      await ref.read(appDataProvider.notifier).updateSettings(s);
      final newData = ref.read(appDataProvider).value ?? AppData();
      await NotificationService.syncReminders(newData);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                sectionHeader(context, '课程提醒'),
                SwitchListTile(
                  title: const Text('上课前提醒'),
                  value: settings.remindersEnabled,
                  onChanged: (v) => update(settings.copyWith(remindersEnabled: v)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownMenu<int>(
                    label: const Text('提前提醒（分钟）'),
                    initialSelection: settings.reminderLeadMinutes,
                    enabled: settings.remindersEnabled,
                    dropdownMenuEntries: [
                      DropdownMenuEntry(value: 1, label: '1 分钟'),
                      DropdownMenuEntry(value: 5, label: '5 分钟'),
                      DropdownMenuEntry(value: 10, label: '10 分钟'),
                      DropdownMenuEntry(value: 15, label: '15 分钟'),
                      DropdownMenuEntry(value: 30, label: '30 分钟'),
                    ],
                    onSelected: (v) => update(
                        settings.copyWith(reminderLeadMinutes: v ?? settings.reminderLeadMinutes)),
                  ),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                sectionHeader(context, '外观'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownMenu<String>(
                    label: const Text('主题模式'),
                    initialSelection: settings.themeMode,
                    dropdownMenuEntries: [
                      DropdownMenuEntry(value: 'system', label: '跟随系统'),
                      DropdownMenuEntry(value: 'light', label: '浅色'),
                      DropdownMenuEntry(value: 'dark', label: '深色'),
                    ],
                    onSelected: (v) => update(settings.copyWith(themeMode: v ?? settings.themeMode)),
                  ),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                sectionHeader(context, '课表'),
                ListTile(
                  leading: const Icon(Icons.table_view),
                  title: const Text('管理课表'),
                  subtitle: Text(
                      '${data.schedules.length} 个课表：新建 / 重命名 / 开学日期 / 周数 / 删除'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SchedulesScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('编辑时间表'),
                  subtitle: const Text('节次时间 / 每节时长（24 小时制）'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PeriodTimesScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_view_week),
                  title: const Text('多时间表'),
                  subtitle: const Text('创建 / 切换 / 删除具名时间表，按周范围过滤课程'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WeekPlansScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget sectionHeader(BuildContext context, String title) {
  final t = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
  );
}
