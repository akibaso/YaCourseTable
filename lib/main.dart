import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'ui/screens/main_screen.dart';

void main() {
  runApp(
    ProviderScope(
      child: MaterialApp(
        title: 'YaCourseTable',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const MainScreen(),
      ),
    ),
  );
}
