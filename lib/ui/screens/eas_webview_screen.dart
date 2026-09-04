import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/parsers/html_parser.dart';
import 'package:ya_coursetable/core/models.dart';

/// 教务系统在线导入（借鉴 WakeUp 的"内置浏览器"方式）：
/// 用户输入教务网址 → 内置 WebView 打开 → 用户自己登录/导航到课表页面 →
/// 一键抓取当前页面 HTML 并解析成课程。
class EasWebviewScreen extends ConsumerStatefulWidget {
  const EasWebviewScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<EasWebviewScreen> createState() => _EasWebviewScreenState();
}

class _EasWebviewScreenState extends ConsumerState<EasWebviewScreen> {
  late final WebViewController _controller;
  final _urlFocus = FocusNode();
  final _urlCtrl = TextEditingController();
  bool _busy = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100),
        onPageFinished: (_) {},
      ));
    final start = widget.initialUrl;
    if (start != null && start.isNotEmpty) {
      _urlCtrl.text = start;
      _load(start);
    }
  }

  @override
  void dispose() {
    _urlFocus.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final withScheme =
        trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
    await _controller.loadRequest(Uri.parse(withScheme));
  }

  Future<void> _grabAndParse() async {
    setState(() => _busy = true);
    try {
      final html = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      // WebView 返回 JSON 字符串（带引号 + 转义），需要解码。
      var htmlStr = html.toString();
      if (htmlStr.startsWith('"') && htmlStr.endsWith('"')) {
        htmlStr = jsonDecode(htmlStr) as String;
      }
      final courses = await Isolate.run(
          () => HtmlParser.parseHtml(htmlStr, 'new_schedule'));
      if (!mounted) return;
      setState(() => _busy = false);
      if (courses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前页面未解析出课程，请确认已打开课表页面')),
        );
        return;
      }
      // 结果确认对话框
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('解析成功'),
          content: Text('共解析出 ${courses.length} 门课程，是否新建课表导入？\n\n导入后请自行检查课程信息是否正确。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('新建课表并导入'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final monday = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      final schedule = Schedule(
        id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
        name: _scheduleNameFromUrl(),
        semesterStartIso: '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}',
      )..courses.addAll(courses);
      await ref.read(appDataProvider.notifier).addSchedule(schedule);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${courses.length} 门课程')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('抓取失败：$e')),
      );
    }
  }

  /// 课表名称用教务系统域名，避免所有导入都叫“教务导入”。
  String _scheduleNameFromUrl() {
    final text = _urlCtrl.text.trim();
    if (text.isEmpty) return '教务导入';
    try {
      final uri = Uri.parse(text.startsWith('http') ? text : 'https://$text');
      if (uri.host.isEmpty) return '教务导入';
      return '${uri.host} 课表';
    } catch (_) {
      return '教务导入';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('教务系统导入'),
        actions: [
          IconButton(
            tooltip: '抓取本页课表',
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            onPressed: _busy ? null : _grabAndParse,
          ),
        ],
      ),
      body: Column(
        children: [
          // 地址栏
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    focusNode: _urlFocus,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '输入教务系统网址',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onSubmitted: _load,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: '前往',
                  onPressed: () => _load(_urlCtrl.text),
                ),
              ],
            ),
          ),
          // 进度条
          if (_progress < 1)
            LinearProgressIndicator(value: _progress, minHeight: 2, color: scheme.primary),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}