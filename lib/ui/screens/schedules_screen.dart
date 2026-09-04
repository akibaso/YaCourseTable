import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/ui/screens/period_times_screen.dart';

/// 多课表管理：新建 / 重命名 / 改开学日期 / 改总周数 / 删除 / 切换。
class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  static String _isoOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtDate(String iso) {
    final d = DateTime.parse(iso);
    return '${d.month}月${d.day}日';
  }

  Future<void> _createSchedule() async {
    final notifier = ref.read(appDataProvider.notifier);
    final monday = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final schedule = Schedule(
      id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
      name: '未命名课表',
      semesterStartIso: _isoOf(monday),
      totalWeeks: 20,
    );
    await notifier.addSchedule(schedule);
    if (!mounted) return;
    _editSchedule(schedule);
  }

  void _editSchedule(Schedule s) {
    final notifier = ref.read(appDataProvider.notifier);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ScheduleEditSheet(
        schedule: s,
        onSave: (updated) => notifier.updateSchedule(updated),
      ),
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课表'),
        content: Text('确定删除“$name”？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(appDataProvider.notifier).deleteSchedule(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider).value ?? AppData();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理课表'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      body: data.schedules.isEmpty
          ? Center(
              child: Text('还没有课表，点右下角“+”新建',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final s in data.schedules)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: data.activeScheduleId == s.id
                          ? Icon(Icons.check_circle, color: scheme.primary)
                          : Icon(Icons.calendar_month, color: scheme.onSurfaceVariant),
                      title: Text(s.name),
                      subtitle: Text(
                          '${s.courses.length} 门课 · ${_fmtDate(s.semesterStartIso)}开学 · ${s.totalWeeks} 周'),
                      isThreeLine: true,
                      onTap: () => ref.read(appDataProvider.notifier).setActiveSchedule(s.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: '编辑课表',
                            onPressed: () => _editSchedule(s),
                          ),
                          IconButton(
                            icon: const Icon(Icons.timer),
                            tooltip: '编辑时间表',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => PeriodTimesScreen(schedule: s)));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除课表',
                            onPressed: () => _confirmDelete(s.id, s.name),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建课表',
        onPressed: _createSchedule,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 课表编辑表单（底部抽屉）：名称 / 开学日期 / 总周数。
class _ScheduleEditSheet extends StatefulWidget {
  final Schedule schedule;
  final ValueChanged<Schedule> onSave;

  const _ScheduleEditSheet({required this.schedule, required this.onSave});

  @override
  State<_ScheduleEditSheet> createState() => _ScheduleEditSheetState();
}

class _ScheduleEditSheetState extends State<_ScheduleEditSheet> {
  late final TextEditingController _nameCtrl;
  late DateTime _start;
  late final TextEditingController _weeksCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.schedule.name);
    _start = DateTime.parse(widget.schedule.semesterStartIso);
    _weeksCtrl = TextEditingController(text: '${widget.schedule.totalWeeks}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weeksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _start = picked);
  }

  void _save() {
    final weeks = int.tryParse(_weeksCtrl.text.trim()) ?? widget.schedule.totalWeeks;
    widget.onSave(
      widget.schedule.copyWith(
        name: _nameCtrl.text.trim().isEmpty ? '未命名课表' : _nameCtrl.text.trim(),
        semesterStartIso:
            '${_start.year}-${_start.month.toString().padLeft(2, '0')}-${_start.day.toString().padLeft(2, '0')}',
        totalWeeks: weeks.clamp(1, 60),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('编辑课表', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '课表名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickStartDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '开学日期',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                  '${_start.year}年${_start.month}月${_start.day}日'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weeksCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '总周数',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
