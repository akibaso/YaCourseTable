import 'dart:convert';

import '../core/models.dart';

/// 在线分享口令：将 AppData 编码为 base64 口令，粘贴口令即可导入。
class SharedLinkParser {
  /// Encode [data] into a share code (base64 of JSON).
  static String encode(AppData data) =>
      base64.encode(utf8.encode(jsonEncode(data.toJson())));

  /// Decode a share code back into [AppData]; returns null when invalid.
  static AppData? parse(String code) {
    try {
      final bytes = base64Decode(code.trim());
      final jsonStr = utf8.decode(bytes);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AppData.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
