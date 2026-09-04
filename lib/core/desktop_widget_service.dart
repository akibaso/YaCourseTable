import 'package:flutter_app_widget/flutter_app_widget.dart';

import 'models.dart';
import 'notification_service.dart';

/// 桌面小部件数据同步（借鉴 WakeUp 的桌面小组件功能）：
/// 把“下一节课”的课程名与时间写入小部件，并通知 AppWidget 刷新。
class DesktopWidgetService {
  /// 小部件 Provider 类名（与 AndroidManifest 的 receiver 一致）。
  static const String providerClass =
      'com.yacoursetable.ya_coursetable.YaWidgetProvider';

  /// 计算最近一次课程并开始时间，写入小部件数据并刷新。
  static Future<void> update(AppData data) async {
    try {
      final occurrences = NotificationService.nextOccurrences(data, 1);
      final next = occurrences.isEmpty ? null : occurrences.first;
      final name = next == null ? '暂无课程' : next.courseName;
      String time = '';
      if (next != null) {
        final at = next.start;
        time =
            '${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
      }
      await FlutterAppWidget.setWidgetDataAndUpdate(
        key: 'course_name',
        value: name,
        androidWidgetProviderClass: providerClass,
      );
      await FlutterAppWidget.setWidgetDataAndUpdate(
        key: 'course_time',
        value: time,
        androidWidgetProviderClass: providerClass,
      );
    } catch (_) {
      // 测试环境或无插件时静默失败，不影响主流程。
    }
  }
}
