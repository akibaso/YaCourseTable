import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';

/// 多时间表管理：为活动课表创建 / 删除 / 切换具名时间表（WeekPlan）。
/// 选中某个时间表后，主界面只显示该时间表周范围内的课程。
class WeekPlansScreen extends ConsumerStatefulWidget {
  const WeekPlansScreen({super.key, this.schedule});

  /// 指定课表；为空时管理活动课表。
  final Schedule? schedule;

  @override
  ConsumerState<WeekPlansScreen> createState() => _WeekPlansScreenState();
}

class _WeekPlansScreenState extends ConsumerState<WeekPlansScreen> {
  static const _parityLabels = {'all': '全部周', 'odd': '单周', 'even': '双周'};

  Schedule? _schedule;

  @override
  void initState() {
    super.initState();
    _schedule =
        widget.schedule ?? (ref.read(appDataProvider).value ?? AppData()).activeSchedule();
  }

  Future<void> _createPlan() async {
    final schedule = _schedule;
    if (schedule == null) return;
    final result = await showDialog<_PlanDraft>(
      context: context,
      builder: (ctx) => _NewPlanDialog(totalWeeks: schedule.totalWeeks),
    );
    if (result == null) return;
    await ref.read(appDataProvider.notifier).addWeekPlan(
      schedule.id,
      WeekPlan(
        id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
        name: result.name,
        weekStart: result.weekStart,
        weekEnd: result.weekEnd,
        oddEven: result.oddEven,
      ),
    );
  }

  Future<void> _deletePlan(WeekPlan plan) async {
    final schedule = _schedule;
    if (schedule == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除时间表'),
        content: Text('确定删除“${plan.name}”？'),
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
      await ref.read(appDataProvider.notifier)
          .deleteWeekPlan(schedule.id, plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除时间表“${plan.name}”')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    final data = ref.watch(appDataProvider).value ?? AppData();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('多时间表'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      body: schedule == null
          ? Center(
              child: Text('还没有课表，请先导入或新建课表',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (schedule.weekPlans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        '该课表还没有时间表，点右下角“+”新建',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                for (final p in schedule.weekPlans)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: data.activeWeekPlanId == p.id
                          ? Icon(Icons.check_circle, color: scheme.primary)
                          : const Icon(Icons.calendar_view_week),
                      title: Text(p.name),
                      subtitle: Text(
                          '第 ${p.weekStart}-${p.weekEnd} 周 · ${_parityLabels[p.oddEven] ?? '全部周'}'),
                      isThreeLine: true,
                      onTap: () => ref.read(appDataProvider.notifier)
                          .setActiveWeekPlan(p.id),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '删除时间表',
                        onPressed: () => _deletePlan(p),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建时间表',
        onPressed: _createPlan,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PlanDraft {
  final String name;
  final int weekStart;
  final int weekEnd;
  final String oddEven;

  _PlanDraft({
    required this.name,
    required this.weekStart,
    required this.weekEnd,
    required this.oddEven,
  });
}

class _NewPlanDialog extends StatefulWidget {
  final int totalWeeks;

  const _NewPlanDialog({required this.totalWeeks});

  @override
  State<_NewPlanDialog> createState() => _NewPlanDialogState();
}

class _NewPlanDialogState extends State<_NewPlanDialog> {
  final _nameCtrl = TextEditingController();
  final _startCtrl = TextEditingController(text: '1');
  final _endCtrl = TextEditingController(text: '20');
  String _parity = 'all';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final start = int.tryParse(_startCtrl.text.trim());
    final end = int.tryParse(_endCtrl.text.trim());
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写时间表名称')));
      return;
    }
    if (start == null || end == null || start < 1 || end > widget.totalWeeks || start > end) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('周范围需为 1-${widget.totalWeeks} 且 开始≤结束')));
      return;
    }
    Navigator.of(context).pop(
      _PlanDraft(name: name, weekStart: start, weekEnd: end, oddEven: _parity),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建时间表'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '如：考试周 / 补课周',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '开始周',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '结束周',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownMenu<String>(
            label: const Text('周次奇偶'),
            initialSelection: _parity,
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'all', label: '全部周'),
              DropdownMenuEntry(value: 'odd', label: '单周'),
              DropdownMenuEntry(value: 'even', label: '双周'),
            ],
            onSelected: (v) => setState(() => _parity = v ?? 'all'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }
}
