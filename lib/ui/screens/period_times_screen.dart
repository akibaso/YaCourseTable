import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_coursetable/core/app_state.dart';
import 'package:ya_coursetable/core/models.dart';

/// 编辑时间表（参照 WakeUp 的“编辑时间表”）：
/// - “每节课时长相同”开关 + “一节课时长”（分钟）
/// - 各节次开始时间输入（24 小时制 HH:MM），结束时间由时长自动推算
class PeriodTimesScreen extends ConsumerStatefulWidget {
  const PeriodTimesScreen({super.key, this.schedule});

  /// 指定课表；为空时编辑活动课表。
  final Schedule? schedule;

  @override
  ConsumerState<PeriodTimesScreen> createState() => _PeriodTimesScreenState();
}

class _PeriodTimesScreenState extends ConsumerState<PeriodTimesScreen> {
  Schedule? _schedule;
  int _periodCount = 10;
  bool _sameLength = true;
  int _periodMinutes = 45;
  late final List<TextEditingController> _startCtrls;
  List<TextEditingController> _endCtrls = [];
  late final TextEditingController _minutesCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule ?? (ref.read(appDataProvider).value ?? AppData()).activeSchedule();
    _schedule = s;
    if (s != null) {
      _periodCount = s.periodTimes.length;
      _startCtrls = s.periodTimes
          .map((t) => TextEditingController(text: _fmtTime(t.startMin)))
          .toList();
      _endCtrls = s.periodTimes
          .map((t) => TextEditingController(text: _fmtTime(t.endMin)))
          .toList();
      final durs = [for (final t in s.periodTimes) t.endMin - t.startMin];
      if (durs.isNotEmpty && durs.toSet().length == 1) {
        _periodMinutes = durs.first;
        _sameLength = true;
      }
    } else {
      _startCtrls = [for (var i = 0; i < _periodCount; i++) TextEditingController()];
    }
    _minutesCtrl = TextEditingController(text: '$_periodMinutes');
  }

  @override
  void dispose() {
    for (final c in _startCtrls) {
      c.dispose();
    }
    for (final c in _endCtrls) {
      c.dispose();
    }
    _minutesCtrl.dispose();
    super.dispose();
  }

  static String _fmtTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static int? _parseTime(String text) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!) ?? 99;
    final mi = int.tryParse(m.group(2)!) ?? 99;
    if (h < 0 || h > 23 || mi < 0 || mi > 59) return null;
    return h * 60 + mi;
  }

  void _addPeriod() {
    setState(() {
      _periodCount = math.min(_periodCount + 1, 20);
      if (_startCtrls.length < _periodCount) {
        _startCtrls.add(TextEditingController());
        _endCtrls.add(TextEditingController());
      }
    });
  }

  void _removePeriod() {
    setState(() {
      _periodCount = math.max(_periodCount - 1, 1);
      while (_startCtrls.length > _periodCount) {
        _startCtrls.removeLast().dispose();
        if (_endCtrls.length > _periodCount) _endCtrls.removeLast().dispose();
      }
    });
  }

  void _save() {
    final schedule = _schedule;
    if (schedule == null) return;
    final minutes = int.tryParse(_minutesCtrl.text.trim()) ?? _periodMinutes;
    final times = <PeriodTime>[];
    for (var i = 0; i < _periodCount; i++) {
      final startMin = _parseTime(_startCtrls[i].text.trim());
      if (startMin == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('第 ${i + 1} 节开始时间无效，请使用 24 小时制 HH:MM')));
        return;
      }
      int endMin;
      if (_sameLength) {
        endMin = startMin + minutes;
        if (endMin > 1439) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('第 ${i + 1} 节结束时间超过 24:00')));
          return;
        }
      } else {
        final endText = i < _endCtrls.length ? _endCtrls[i].text.trim() : '';
        final e = _parseTime(endText);
        if (e == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('第 ${i + 1} 节结束时间无效，请使用 24 小时制 HH:MM')));
          return;
        }
        if (e <= startMin) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('第 ${i + 1} 节结束时间必须晚于开始时间')));
          return;
        }
        endMin = e;
      }
      times.add(PeriodTime(startMin: startMin, endMin: endMin));
    }
    ref.read(appDataProvider.notifier).updateSchedule(schedule.copyWith(periodTimes: times));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('时间表已更新')));
    Navigator.of(context).pop();
  }

  List<Widget> _buildPeriodRows(TextTheme t, ColorScheme scheme) {
    final rows = <Widget>[];
    for (var i = 0; i < _periodCount; i++) {
      final startMin = _parseTime(_startCtrls[i].text.trim()) ?? 0;
      final minutes = int.tryParse(_minutesCtrl.text.trim()) ?? _periodMinutes;
      final Widget endWidget;
      if (_sameLength) {
        endWidget = Text(
          _fmtTime(startMin + minutes),
          style: t.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
        );
      } else {
        endWidget = SizedBox(
          width: 88,
          child: TextField(
            controller: i < _endCtrls.length ? _endCtrls[i] : null,
            enabled: i < _endCtrls.length,
            textAlign: TextAlign.end,
            style: t.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        );
      }
      rows.add(
        Row(
          children: [
            SizedBox(
              width: 64,
              child: Text('第 ${i + 1} 节', style: t.bodyMedium),
            ),
            Expanded(
              child: TextField(
                controller: _startCtrls[i],
                keyboardType: TextInputType.text,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('-'),
            ),
            endWidget,
          ],
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑时间表'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              '保存',
              style: TextStyle(color: scheme.primary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('每节课时长相同'),
                  value: _sameLength,
                  onChanged: (v) => setState(() => _sameLength = v),
                ),
                ListTile(
                  title: const Text('一节课时长'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 56,
                        child: TextField(
                          controller: _minutesCtrl,
                          enabled: _sameLength,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '分钟',
                        style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '请注意是 24 小时制！',
            style: t.bodyMedium?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final row in _buildPeriodRows(t, scheme)) row,
                const Divider(),
                // 节次数量调整
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('节次数量', style: t.bodyMedium),
                      const Spacer(),
                      Text('$_periodCount', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: '减少一节',
                        onPressed: _periodCount > 1 ? _removePeriod : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: '增加一节',
                        onPressed: _periodCount < 20 ? _addPeriod : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
