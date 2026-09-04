import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';

/// 添加/编辑课程（借鉴 WakeUp 的课程编辑）：课程信息 + 多个时间段（星期/节次/周范围/单双周）。
class AddCourseScreen extends ConsumerStatefulWidget {
  /// When editing an existing course, pass it together with its [scheduleId].
  const AddCourseScreen({super.key, this.course, this.scheduleId});

  final Course? course;
  final String? scheduleId;

  @override
  ConsumerState<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends ConsumerState<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _teacher;
  late final TextEditingController _venue;
  late final TextEditingController _campus;
  late final TextEditingController _className;
  late final TextEditingController _notes;

  /// 时间段编辑：day(1..7), start, end, weekStart, weekEnd, oddEven。
  final _slots = <_SlotDraft>[];

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _name = TextEditingController(text: c?.name ?? '');
    _teacher = TextEditingController(text: c?.teacher ?? '');
    _venue = TextEditingController(text: c?.venue ?? '');
    _campus = TextEditingController(text: c?.campus ?? '');
    _className = TextEditingController(text: c?.className ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    if (c != null) {
      for (final s in c.timeSlots) {
        final ws = s.weekSpec;
        _slots.add(_SlotDraft(
          day: s.dayOfWeek,
          start: s.startPeriod,
          end: s.endPeriod,
          weekStart: ws.weeks.isNotEmpty ? ws.weeks.first : 1,
          weekEnd: ws.weeks.length > 1 ? ws.weeks[1] : 20,
          oddEven: ws.oddEven,
        ));
      }
    }
    if (_slots.isEmpty) _slots.add(_SlotDraft());
  }

  @override
  void dispose() {
    _name.dispose();
    _teacher.dispose();
    _venue.dispose();
    _campus.dispose();
    _className.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_slots.isEmpty) return;
    final data = ref.read(appDataProvider).value ?? AppData();
    final scheduleId = (widget.scheduleId != null && widget.scheduleId!.isNotEmpty)
        ? widget.scheduleId!
        : data.activeScheduleId;
    final slots = <TimeSlot>[
      for (final d in _slots)
        TimeSlot(
          dayOfWeek: d.day,
          startPeriod: d.start,
          endPeriod: d.end,
          weekSpec: WeekSpec(
            weeks: [d.weekStart, d.weekEnd],
            oddEven: d.oddEven,
          ),
        ),
    ];
    final course = widget.course ??
        Course(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}',
          scheduleId: scheduleId,
          name: '',
          timeSlots: [],
        );
    final updated = Course(
      id: course.id,
      scheduleId: scheduleId,
      name: _name.text.trim(),
      teacher: _teacher.text.trim().isEmpty ? null : _teacher.text.trim(),
      venue: _venue.text.trim().isEmpty ? null : _venue.text.trim(),
      campus: _campus.text.trim().isEmpty ? null : _campus.text.trim(),
      className: _className.text.trim().isEmpty ? null : _className.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      credit: course.credit,
      timeSlots: slots,
    );

    if (widget.course == null) {
      // 添加到当前活动课表
      final schedule = data.schedules
          .firstWhere((s) => s.id == scheduleId, orElse: () => data.schedules.first);
      final newSchedule = Schedule(
        id: schedule.id,
        name: schedule.name,
        semesterStartIso: schedule.semesterStartIso,
        totalWeeks: schedule.totalWeeks,
        settings: schedule.settings,
        weekPlans: schedule.weekPlans,
        courses: [...schedule.courses, updated],
      );
      await ref.read(appDataProvider.notifier).updateSchedule(newSchedule);
    } else {
      final schedule = data.schedules.firstWhere((s) => s.id == scheduleId,
          orElse: () => data.schedules.first);
      final newSchedule = Schedule(
        id: schedule.id,
        name: schedule.name,
        semesterStartIso: schedule.semesterStartIso,
        totalWeeks: schedule.totalWeeks,
        settings: schedule.settings,
        weekPlans: schedule.weekPlans,
        courses: [
          for (final c in schedule.courses)
            if (c.id == updated.id) updated else c,
        ],
      );
      await ref.read(appDataProvider.notifier).updateSchedule(newSchedule);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course == null ? '添加课程' : '编辑课程'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('课程信息', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '课程名称 *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '课程名称必填' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _teacher,
              decoration: const InputDecoration(labelText: '教师'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venue,
              decoration: const InputDecoration(labelText: '场地'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _campus,
              decoration: const InputDecoration(labelText: '校区'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _className,
              decoration: const InputDecoration(labelText: '教学班'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('上课时间段（至少一个）',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '添加时间段',
                  onPressed: () => setState(() => _slots.add(_SlotDraft())),
                ),
              ],
            ),
            for (var i = 0; i < _slots.length; i++) _SlotEditor(
              key: ValueKey(i),
              draft: _slots[i],
              index: i,
              removable: _slots.length > 1,
              onRemove: () => setState(() => _slots.removeAt(i)),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('保存课程'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotDraft {
  int day;
  int start;
  int end;
  int weekStart;
  int weekEnd;
  String oddEven;

  _SlotDraft({
    this.day = 1,
    this.start = 1,
    this.end = 2,
    this.weekStart = 1,
    this.weekEnd = 20,
    this.oddEven = 'all',
  });
}

class _SlotEditor extends StatelessWidget {
  final _SlotDraft draft;
  final int index;
  final bool removable;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _SlotEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.removable,
    required this.onRemove,
    required this.onChanged,
  });

  static const _days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('时间段 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (removable)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '删除时间段',
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<int>(
                  value: draft.day,
                  items: [
                    for (var d = 0; d < 7; d++)
                      DropdownMenuItem(value: d + 1, child: Text(_days[d])),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      draft.day = v;
                      onChanged();
                    }
                  },
                ),
                DropdownButton<int>(
                  value: draft.start,
                  items: [
                    for (var p = 1; p <= 12; p++)
                      DropdownMenuItem(value: p, child: Text('第$p节')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      draft.start = v;
                      onChanged();
                    }
                  },
                ),
                Text('至'),
                DropdownButton<int>(
                  value: draft.end,
                  items: [
                    for (var p = 1; p <= 12; p++)
                      DropdownMenuItem(value: p, child: Text('第$p节')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      draft.end = v;
                      onChanged();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<int>(
                  value: draft.weekStart,
                  items: [
                    for (var w = 1; w <= 25; w++)
                      DropdownMenuItem(value: w, child: Text('第$w周')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      draft.weekStart = v;
                      onChanged();
                    }
                  },
                ),
                Text('至'),
                DropdownButton<int>(
                  value: draft.weekEnd,
                  items: [
                    for (var w = 1; w <= 25; w++)
                      DropdownMenuItem(value: w, child: Text('第$w周')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      draft.weekEnd = v;
                      onChanged();
                    }
                  },
                ),
                DropdownButton<String>(
                  value: draft.oddEven,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('每周')),
                    DropdownMenuItem(value: 'odd', child: Text('单周')),
                    DropdownMenuItem(value: 'even', child: Text('双周')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      draft.oddEven = v;
                      onChanged();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}