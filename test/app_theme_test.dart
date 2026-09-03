import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ya_coursetable/app_theme.dart';

void main() {
  test('light theme is Material 3 with seeded ColorScheme', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, isNotNull);
    expect(theme.colorScheme.brightness, Brightness.light);
  });

  test('dark theme is Material 3 with dark brightness', () {
    final theme = AppTheme.dark();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.dark);
  });
}
