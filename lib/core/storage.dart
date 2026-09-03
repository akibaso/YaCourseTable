import 'dart:convert';
import 'dart:io';

import '../core/models.dart';

/// JSON file storage shared by the app and the native Android widgets.
/// Path-based so pure-Dart tests can pass a temp path.
class Storage {
  static Future<AppData> load(String path) async {
    final file = File(path);
    if (!await file.exists()) return AppData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return AppData();
    return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> save(String path, AppData data) async {
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(data.toJson()), flush: true);
  }
}
