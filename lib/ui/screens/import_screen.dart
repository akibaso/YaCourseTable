
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/core/import_service.dart';
import 'package:ya_coursetable/core/models.dart';
// dart:convert is used by ImportService (backup JSON), kept here for parity.

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

  Future<void> _run(Future<ImportResult> Function() action) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    await _showResult(result);
  }

  void _runSync(ImportResult Function() action) {
    setState(() => _busy = true);
    final result = action();
    setState(() => _busy = false);
    _showResult(result);
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
              name: '导入课表',
              semesterStartIso: _mondayOf(DateTime.now()),
            )..courses.addAll(result.courses),
          ],
        );
    // TODO(Task 5/6 wiring): persist into the global AppData provider
    // once a state provider exists. For now the parsed data stays in
    // memory; the JSON storage layer is wired in Task 4.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '已导入 ${data.schedules.first.courses.length} 门课程到“${data.schedules.first.name}”'),
      ),
    );
  }

  static String _newId() => 'sched_${DateTime.now().millisecondsSinceEpoch}';

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

  String? _easType;

  Widget _buildEasTab(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('选择教务系统类型（参考 WakeUp 支持的教务系统）：',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in const [
              '新URP系统', 'URP系统', '正方教务', '强智教务',
              '旧强智教务', '树维教务', '重庆大学', '研究生教务', '申请适配',
            ])
              ActionChip(
                label: Text(t),
                backgroundColor:
                    _easType == t ? Theme.of(context).colorScheme.secondaryContainer : null,
                onPressed: () => setState(() => _easType = t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _easUrl,
          decoration: const InputDecoration(
            labelText: '课表页面链接',
            hintText: 'https://jw.cug.edu.cn/.../kbcx.aspx',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () {
                  final url = _easUrl.text.trim();
                  if (url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先填写课表页面链接')),
                    );
                    return;
                  }
                  _run(() => _import.importFromEas(url, _easType ?? 'generic'));
                },
          icon: const Icon(Icons.cloud_download),
          label: const Text('在线导入'),
        ),
        const SizedBox(height: 12),
        Text(
          '提示：导入后请自行检查课程信息是否正确（参考 WakeUp）。',
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
        Text('支持文件：PDF / Excel(xls,xlsx) / CSV / HTML / App 备份(JSON)',
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
                : () => _runSync(
                      () => _import.importFromFileBytes(_pickedFileName!, _pickedBytes!),
                    ),
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
                  _runSync(() => _import.importFromShareCode(code));
                },
          icon: const Icon(Icons.link),
          label: const Text('导入口令'),
        ),
      ],
    );
  }
}