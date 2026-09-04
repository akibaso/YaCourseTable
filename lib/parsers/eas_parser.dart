import 'package:http/http.dart' as http;

import '../core/models.dart';
import 'html_parser.dart';

/// 教务系统（EAS）在线导入：按教务类型抓取并解析课表页面。
/// 支持类型（参考 WakeUp 文档）：新URP / URP / 正方 / 强智 / 旧强智 / 树维 / 重庆大学 / 研究生教务 / 申请适配。
class EasParser {
  static const List<String> easTypes = [
    '新URP系统',
    'URP系统',
    '正方教务',
    '强智教务',
    '旧强智教务',
    '树维教务',
    '重庆大学',
    '研究生教务',
    '申请适配',
  ];

  /// Fetch [url] (a course schedule page from a school EAS) and parse it.
  static Future<List<Course>> parseUrl(
    String url,
    String scheduleId, {
    String easType = 'generic',
  }) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return [];
    return HtmlParser.parseHtml(res.body, scheduleId);
  }
}
