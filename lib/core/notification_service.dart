import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart';

import 'models.dart';
import 'weeks.dart';

/// 一次课程开始事件（课程名 + 开始时间）。
class Occurrence {
  final String courseName;
  final DateTime start;

  Occurrence({required this.courseName, required this.start});
}

/// 课程提醒通知（借鉴 WakeUp 的上课提醒功能）：
/// 为活动课表里接下来的课程安排本地通知，提前量由 AppSettings.reminderLeadMinutes 控制。
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'course_reminder';
  static const String _channelName = '课程提醒';

  /// 初始化通知（Android 通道 + iOS 权限请求）。
  static Future<bool?> init() {
    return _plugin.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings(''),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
  }

  /// 活动课表中接下来最多 [limit] 次课程开始事件（按开始时间升序）。
  static List<Occurrence> nextOccurrences(AppData data, int limit) {
    final schedule = data.activeSchedule();
    if (schedule == null || schedule.courses.isEmpty) return [];
    final now = DateTime.now();
    final start = DateTime.parse(schedule.semesterStartIso);
    final currentWeek = Weeks.currentWeek(start, now);
    final times = schedule.periodTimes;
    final result = <Occurrence>[];
    for (var w = math.max(currentWeek, 1); w <= schedule.totalWeeks; w++) {
      for (final (course, slot) in Weeks.slotsForWeek(schedule, w)) {
        final dayOffset = (w - 1) * 7 + (slot.dayOfWeek - 1);
        final at = start
            .add(Duration(days: dayOffset))
            .add(Duration(minutes: times[slot.startPeriod - 1].startMin));
        if (!at.isAfter(now)) continue;
        result.add(Occurrence(courseName: course.name, start: at));
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result.take(limit).toList();
  }

  /// 同步提醒：先取消已排通知，再按提前量重新安排。
  static Future<void> syncReminders(AppData data) async {
    final occurrences = nextOccurrences(data, 20);
    if (!data.settings.remindersEnabled || occurrences.isEmpty) {
      await _plugin.cancelAll();
      return;
    }
    await _plugin.cancelAll();
    final lead = data.settings.reminderLeadMinutes;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '课程开始前的提醒',
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (var i = 0; i < occurrences.length; i++) {
      final at = occurrences[i].start.subtract(Duration(minutes: lead));
      if (!at.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        id: 1000 + i,
        scheduledDate: TZDateTime.local(
            at.year, at.month, at.day, at.hour, at.minute, at.second),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        title: '即将上课',
        body: '${occurrences[i].courseName}（提前 ${data.settings.reminderLeadMinutes} 分钟提醒）',
      );
    }
  }
}
