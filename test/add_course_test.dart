import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/app_theme.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/ui/screens/add_course_screen.dart';

void main() {
  testWidgets('添加课程表单校验：课程名必填、可保存两个时间段', (tester) async {
    final data = AppData(
      activeScheduleId: 'a',
      schedules: [
        Schedule(id: 'a', name: '我的课表', semesterStartIso: '2026-09-07'),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    // AddCourseScreen 必须在一个可 pop 的路由里（保存成功后 pop 返回）。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDataProvider.overrideWith((ref) => _Seed(ref, data))],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(builder: (_) => const AddCourseScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 空课程名保存 → 校验失败
    await tester.tap(find.text('保存课程'));
    await tester.pump();
    expect(find.text('课程名称必填'), findsOneWidget);

    // 填写名称 + 两个时间段
    await tester.enterText(find.widgetWithText(TextFormField, '课程名称 *'), '高等数学');
    await tester.tap(find.byTooltip('添加时间段'));
    await tester.pump();
    expect(find.text('时间段 1'), findsOneWidget);
    expect(find.text('时间段 2'), findsOneWidget);

    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();
    // 保存成功后返回上一页
    expect(find.byType(AddCourseScreen), findsNothing);
  });
}

class _Seed extends AppDataNotifier {
  _Seed(super.ref, AppData data) : super() {
    state = AsyncValue<AppData>.data(data);
  }
}