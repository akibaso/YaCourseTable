import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/app_theme.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/ui/screens/main_screen.dart';
import 'package:ya_coursetable/ui/widgets/day_view.dart';
import 'package:ya_coursetable/ui/widgets/schedule_switcher.dart';
import 'package:ya_coursetable/ui/widgets/week_axis.dart';

void main() {
  testWidgets('full main screen with 2 schedules', (tester) async {
    final data = AppData(
      activeScheduleId: 'a',
      schedules: [
        Schedule(id: 'a', name: '我的课表', semesterStartIso: '2026-09-07', totalWeeks: 20,
          courses: [
            Course(id: 'c1', scheduleId: 'a', name: '高等数学', timeSlots: [
              TimeSlot(dayOfWeek: 1, startPeriod: 1, endPeriod: 2, weekSpec: WeekSpec(weeks: [1, 20]))]),
          ]),
        Schedule(id: 'b', name: '第二课表', semesterStartIso: '2026-09-07'),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [appDataProvider.overrideWith((ref) => _Seed(ref, data))],
      child: MaterialApp(theme: AppTheme.light(), home: const MainScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('添加课程'), findsOneWidget);
    expect(find.byTooltip('导入课表'), findsOneWidget);
    expect(find.byTooltip('导出课表'), findsOneWidget);
    expect(find.byTooltip('选择周'), findsOneWidget);
    expect(find.byType(WeekAxis), findsOneWidget);
    // PageView 会构建当前页与相邻页的 DayView（≥1 个）
    expect(find.byType(DayView), findsWidgets);
    expect(find.byType(ScheduleSwitcher), findsOneWidget);
    expect(find.text('第二课表'), findsOneWidget);
  });
}

class _Seed extends AppDataNotifier {
  _Seed(super.ref, AppData data) : super() {
    state = AsyncValue<AppData>.data(data);
  }
}
