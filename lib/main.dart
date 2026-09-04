import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ya_coursetable/app_theme.dart';
import 'package:ya_coursetable/core/app_state.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YaCourseTable',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const MainScreen(),
    );
  }
}