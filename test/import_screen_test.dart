import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/core/import_service.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/parsers/shared_link_parser.dart';
import 'package:ya_coursetable/ui/screens/import_screen.dart';

void main() {
  testWidgets('导入课表：分享口令粘贴后能够解析', (tester) async {
    // 构造一个 AppData 备份并编码为口令
    final data = AppData(
      activeScheduleId: 'a',
      schedules: [
        Schedule(
          id: 'a',
          name: '我的课表',
          semesterStartIso: '2026-09-07',
          courses: [
            Course(
              id: 'c1',
              scheduleId: 'a',
              name: '高等数学',
              teacher: '张三',
              timeSlots: [
                TimeSlot(dayOfWeek: 1, startPeriod: 1, endPeriod: 2),
              ],
            ),
          ],
        ),
      ],
    );
    final code = base64.encode(utf8.encode(jsonEncode(data.toJson())));

    await tester.pumpWidget(
      MaterialApp(home: ImportScreen()),
    );

    // 切到“分享口令”tab
    await tester.tap(find.text('分享口令'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, code);
    await tester.tap(find.text('导入口令'));
    await tester.pumpAndSettle();

    expect(find.text('导入结果'), findsOneWidget);
    expect(find.textContaining('口令包含 1 个课表'), findsOneWidget);
  });

  test('ImportService: 分享口令 round-trip', () {
    final svc = ImportService();
    final data = AppData(
      schedules: [
        Schedule(id: 's1', name: '课表1', semesterStartIso: '2026-09-07'),
      ],
    );
    final code = SharedLinkParser.encode(data);
    final result = svc.importFromShareCode(code);
    expect(result.isBackup, isTrue);
    expect(result.appData!.schedules.single.name, '课表1');
  });

  test('ImportService: CSV 文件解析', () {
    final svc = ImportService();
    final csv = '时间段,节次,星期一,星期二,星期三,星期四,星期五,星期六,星期日\n'
        '"上午","1-2","模拟电子技术*\n(1-2节)1-5周,7-12周/教师:葛健",,,\n';
    final result = svc.importFromFileBytes('课表.csv', utf8.encode(csv));
    expect(result.courses.length, greaterThan(0));
    expect(result.courses.first.name, contains('模拟电子技术'));
  });

  test('ImportService: 不支持的扩展名提示', () {
    final svc = ImportService();
    final result = svc.importFromFileBytes('notes.txt', utf8.encode('x'));
    expect(result.courses, isEmpty);
    expect(result.message, contains('不支持的文件类型'));
  });
}