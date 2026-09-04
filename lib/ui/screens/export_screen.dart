import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/export_service.dart';
import 'package:ya_coursetable/core/models.dart';

/// 导出课表：备份 JSON / ICS 日历 / 分享口令（借鉴 WakeUp 的导出/分享能力）。
class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider).value ?? AppData();
    final scheme = Theme.of(context).colorScheme;

    Future<void> shareBackup() async {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/coursetable_backup.json');
      await file.writeAsString(ExportService.backupJson(data));
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: ['YaCourseTable备份.json'],
      ));
      if (!context.mounted) return;
      _snack(context, '已调起分享：备份 JSON');
    }

    Future<void> shareIcs() async {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/coursetable.ics');
      await file.writeAsString(ExportService.toIcs(data));
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/calendar')],
        fileNameOverrides: ['YaCourseTable.ics'],
      ));
      if (!context.mounted) return;
      _snack(context, '已调起分享：ICS 日历文件');
    }

    Future<void> shareCode() async {
      final code = ExportService.shareCode(data);
      await Clipboard.setData(ClipboardData(text: code));
      await SharePlus.instance.share(ShareParams(text: code));
      if (!context.mounted) return;
      _snack(context, '分享口令已复制到剪贴板');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出课表'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _ExportTile(
            icon: Icons.backup,
            title: '备份文件（JSON）',
            subtitle: '导出完整 AppData（多课表 + 多时间表），可用于重新导入',
            onTap: shareBackup,
          ),
          _ExportTile(
            icon: Icons.calendar_month,
            title: '日历文件（ICS）',
            subtitle: '把课程事件导入系统日历',
            onTap: shareIcs,
          ),
          _ExportTile(
            icon: Icons.link,
            title: '分享口令',
            subtitle: '生成 base64 口令，他人粘贴即可导入（借鉴 WakeUp 的分享方式）',
            onTap: shareCode,
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(icon: icon),
        title: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: t.bodySmall),
      ),
    );
  }
}

class CircleAvatar extends StatelessWidget {
  final IconData icon;
  const CircleAvatar({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
      child: Icon(icon, color: scheme.onSecondaryContainer),
    );
  }
}
