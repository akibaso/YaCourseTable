import 'dart:convert';
import 'dart:isolate';

import '../core/models.dart';
import '../parsers/csv_parser.dart';
import '../parsers/excel_parser.dart';
import '../parsers/html_parser.dart';
import '../parsers/pdf_parser.dart';
import '../parsers/shared_link_parser.dart';

/// Result of an import attempt.
class ImportResult {
  /// Parsed courses (when the import was a course-source import).
  final List<Course> courses;

  /// A whole backup AppData (when the import was a 备份文件 / 分享口令).
  final AppData? appData;

  /// Human-readable outcome, e.g. "成功解析 12 门课程".
  final String message;

  const ImportResult({
    this.courses = const [],
    this.appData,
    required this.message,
  });

  bool get isBackup => appData != null;
}

/// Course import service (借鉴 WakeUp 的导入实现):
/// - 从教务系统在线 URL 抓取并解析
/// - 从文件（PDF / Excel / CSV / HTML / 备份 JSON）解析
/// - 从分享口令（base64 JSON）导入
class ImportService {
  /// Parse an imported file by its name/extension.
  ImportResult importFromFileBytes(String name, List<int> bytes) {
    return _parseFileDispatch(name, bytes);
  }

  /// Same as [importFromFileBytes] but runs in a background isolate so the
  /// UI thread never blocks (fixes the "app freezes after import" issue).
  Future<ImportResult> importFromFileBytesIsolated(String name, List<int> bytes) {
    return Isolate.run(() => _parseFileDispatch(name, bytes));
  }

  static ImportResult _parseFileDispatch(String name, List<int> bytes) {
    final lower = name.toLowerCase();
    List<Course> courses = const [];
    AppData? backup;
    String message = '';

    if (lower.endsWith('.json') || lower.endsWith('.yct')) {
      // App 备份文件：直接恢复 AppData。
      try {
        final data = AppData.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        backup = data;
        message = '备份文件包含 ${data.schedules.length} 个课表。';
      } catch (_) {
        return const ImportResult(message: '备份文件格式不正确，无法解析。');
      }
    } else if (lower.endsWith('.pdf')) {
      courses = PdfParser.parse(bytes, 'new_schedule');
      message = _countMessage(courses, 'PDF');
    } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      courses = ExcelParser.parseBytes(bytes, 'new_schedule');
      message = _countMessage(courses, 'Excel');
    } else if (lower.endsWith('.csv')) {
      courses = CsvParser.parseText(utf8.decode(bytes, allowMalformed: true), 'new_schedule');
      message = _countMessage(courses, 'CSV');
    } else if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      courses = HtmlParser.parseHtml(utf8.decode(bytes, allowMalformed: true), 'new_schedule');
      message = _countMessage(courses, 'HTML');
    } else {
      return ImportResult(message: '不支持的文件类型：$name（支持 PDF / Excel / CSV / HTML / JSON 备份）。');
    }

    if (backup != null) {
      return ImportResult(appData: backup, message: message);
    }
    return ImportResult(courses: courses, message: message);
  }

  /// Parse a 分享口令 (base64-encoded AppData JSON).
  ImportResult importFromShareCode(String code) {
    final data = SharedLinkParser.parse(code);
    if (data == null) {
      return const ImportResult(message: '口令无效或已损坏，无法解析。');
    }
    return ImportResult(
      appData: data,
      message: '口令包含 ${data.schedules.length} 个课表。',
    );
  }

  static String _countMessage(List<Course> courses, String source) {
    if (courses.isEmpty) return '$source 未解析出课程，请检查文件内容。';
    return '$source 成功解析 ${courses.length} 门课程。';
  }
}