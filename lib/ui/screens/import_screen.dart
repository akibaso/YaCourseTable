
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/import_service.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/ui/screens/eas_webview_screen.dart';

/// Parsed file selection result (injected for tests).
typedef FilePickerResult = ({String name, List<int> bytes});

/// 导入课表（借鉴 WakeUp）：从教务系统在线导入、从文件导入、从分享口令导入。
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, this.filePicker});

  /// Test hook: override file picking (defaults to FilePicker.pickFiles).
  final Future<FilePickerResult?> Function()? filePicker;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen>
    with SingleTickerProviderStateMixin {
  final _easUrl = TextEditingController();
  final _shareCode = TextEditingController();
  late final TabController _tabs;
  final _import = ImportService();
  String _importSource = '导入课表';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _easUrl.dispose();
    _shareCode.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _runSync(ImportResult Function() action) {
    setState(() => _busy = true);
    final result = action();
    setState(() => _busy = false);
    _showResult(result);
  }

  /// 重解析放后台 isolate，UI 不再卡死（修复"导入后直接卡死"）。
  Future<void> _runIsolated(Future<ImportResult> Function() action) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    await _showResult(result);
  }

  Future<void> _showResult(ImportResult result) async {
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入结果'),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _createSchedule(result);
            },
            child: const Text('新建课表并导入'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    navigator.pop();
  }

  void _createSchedule(ImportResult result) {
    final data = result.appData ??
        AppData(
          schedules: [
            Schedule(
              id: _newId(),
              name: _nameFromFile(_pickedFileName),
              semesterStartIso: _mondayOf(DateTime.now()),
            )..courses.addAll(result.courses),
          ],
        );
    // 持久化到全局 AppData（多课表）：备份文件恢复整个 AppData，
    // 课程类导入则新建一个课表并把解析结果写进去。
    if (result.isBackup) {
      ref.read(appDataProvider.notifier).saveAll(data);
    } else {
      for (final s in data.schedules) {
        ref.read(appDataProvider.notifier).addSchedule(s);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '已导入 ${data.schedules.first.courses.length} 门课程到“${data.schedules.first.name}”'),
      ),
    );
  }

  static String _newId() => 'sched_${DateTime.now().millisecondsSinceEpoch}';

  /// 从文件名（去掉扩展名）派生课表名称；分享口令等场景用来源名。
  String _nameFromFile(String? fileName) {
    final fallback = _importSource;
    if (fileName == null) return fallback;
    var base = fileName;
    final idx = base.lastIndexOf('.');
    if (idx > 0) base = base.substring(0, idx);
    return base.isEmpty ? fallback : base;
  }

  static String _mondayOf(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('导入课表', style: TextStyle(color: scheme.onSurface)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '教务系统'),
            Tab(text: '从文件'),
            Tab(text: '分享口令'),
          ],
        ),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildEasTab(scheme),
                _buildFileTab(scheme),
                _buildShareTab(scheme),
              ],
            ),
    );
  }

  Widget _buildEasTab(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('在内置浏览器中打开教务系统，登录后进入课表页面，一键抓取解析：',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _easUrl,
          decoration: const InputDecoration(
            labelText: '教务系统网址',
            hintText: 'jw.cug.edu.cn',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            final url = _easUrl.text.trim();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EasWebviewScreen(
                  initialUrl: url.isEmpty ? null : url,
                ),
              ),
            );
          },
          icon: const Icon(Icons.public),
          label: const Text('在内置浏览器中打开'),
        ),
        const SizedBox(height: 12),
        Text(
          '支持 WakeUp 兼容的教务类型：新URP / URP / 正方 / 强智 / 旧强智 / 树维 / 重庆大学 / 研究生教务。\n提示：导入后请自行检查课程信息是否正确。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String? _pickedFileName;
  List<int>? _pickedBytes;

  Widget _buildFileTab(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('支持文件：PDF / Excel(xls,xlsx) / CSV / HTML / ICS / App 备份(JSON)',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _pickFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('选择文件'),
        ),
        if (_pickedFileName != null) ...[
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(_pickedFileName!),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy || _pickedBytes == null
                ? null
                : () {
                    // ICS 导入需要活动课表的开学日期与节次时间。
                    final active =
                        (ref.read(appDataProvider).value ?? AppData()).activeSchedule();
                    _runIsolated(
                      () => _import.importFromFileBytesIsolated(
                        _pickedFileName!,
                        _pickedBytes!,
                        semesterStartIso: active?.semesterStartIso,
                        periodTimes: active?.periodTimes,
                      ),
                    );
                  },
            icon: const Icon(Icons.upload_file),
            label: const Text('解析并导入'),
          ),
        ],
      ],
    );
  }

  Future<void> _pickFile() async {
    final picker = await (widget.filePicker ?? _defaultFilePicker)();
    if (picker == null) return;
    setState(() {
      _pickedFileName = picker.name;
      _pickedBytes = picker.bytes;
    });
  }

  Future<FilePickerResult?> _defaultFilePicker() async {
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    return (
      name: file.name,
      bytes: file.bytes ?? await file.xFile.readAsBytes(),
    );
  }

  Widget _buildShareTab(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('粘贴他人分享的课表口令（base64 编码的备份 JSON）：',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _shareCode,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '分享口令',
            hintText: '粘贴口令…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () {
                  final code = _shareCode.text.trim();
                  if (code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先粘贴分享口令')),
                    );
                    return;
                  }
                  _importSource = '共享课表';
                  _runSync(() => _import.importFromShareCode(code));
                },
          icon: const Icon(Icons.link),
          label: const Text('导入口令'),
        ),
      ],
    );
  }
}