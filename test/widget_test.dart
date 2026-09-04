import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ya_coursetable/app_theme.dart';
import 'package:ya_coursetable/ui/screens/main_screen.dart';

void main() {
  testWidgets('MainScreen renders toolbar actions and placeholder body', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MainScreen(),
        ),
      ),
    );

    // Toolbar buttons: add course / import / export / more.
    expect(find.byTooltip('添加课程'), findsOneWidget);
    expect(find.byTooltip('导入课表'), findsOneWidget);
    expect(find.byTooltip('导出课表'), findsOneWidget);
    expect(find.byTooltip('更多功能'), findsOneWidget);
    // Placeholder body text.
    expect(find.text('周数轴 / 课表网格（Task 4）'), findsOneWidget);
  });
}
